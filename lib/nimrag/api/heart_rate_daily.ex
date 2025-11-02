defmodule Nimrag.Api.HeartRateDaily do
  @moduledoc """
  All-day heart rate samples for a single calendar date.
  """

  @typedoc "Single heart rate data point."
  @type point :: %{
          timestamp: DateTime.t(),
          bpm: non_neg_integer(),
          source: String.t() | nil
        }

  @type t :: %__MODULE__{
          date: Date.t(),
          resting_heart_rate: non_neg_integer() | nil,
          points: [point()]
        }

  defstruct date: nil, resting_heart_rate: nil, points: []

  @spec from_api_response(map() | binary()) :: {:ok, t()} | {:error, term()}
  def from_api_response(body) when is_binary(body) do
    with {:ok, decoded} <- Jason.decode(body) do
      from_api_response(decoded)
    end
  end

  def from_api_response(%{} = body) do
    with {:ok, date} <- parse_date(body),
         {:ok, points} <- parse_points(body) do
      {:ok,
       %__MODULE__{
         date: date,
         resting_heart_rate: Map.get(body, "restingHeartRate"),
         points: points
       }}
    else
      {:error, reason} -> {:error, {:invalid_response, reason, body}}
    end
  end

  def from_api_response(other),
    do: {:error, {:invalid_response, :unsupported_body, other}}

  defp parse_date(body) do
    body
    |> fetch_first(~w(calendarDate summaryDate date))
    |> case do
      nil ->
        {:error, :missing_date}

      iso when is_binary(iso) ->
        Date.from_iso8601(iso)

      _ ->
        {:error, :invalid_date}
    end
  end

  defp parse_points(body) do
    body
    |> fetch_first(~w(heartRateValues heartRateValue heartRate))
    |> case do
      nil ->
        {:ok, []}

      values when is_list(values) ->
        {:ok,
         values
         |> Enum.reduce([], fn entry, acc ->
           case parse_point(entry) do
             {:ok, point} -> [point | acc]
             :skip -> acc
           end
         end)
         |> Enum.reverse()}

      _ ->
        {:error, :invalid_points}
    end
  end

  defp parse_point([timestamp, bpm]) when is_integer(bpm) do
    with {:ok, dt} <- cast_timestamp(timestamp) do
      {:ok, %{timestamp: dt, bpm: bpm, source: nil}}
    else
      _ -> :skip
    end
  end

  defp parse_point([timestamp, bpm, source]) when is_integer(bpm) do
    with {:ok, dt} <- cast_timestamp(timestamp) do
      {:ok, %{timestamp: dt, bpm: bpm, source: normalize_source(source)}}
    else
      _ -> :skip
    end
  end

  defp parse_point(%{"heartRateValue" => bpm, "timestamp" => timestamp}) do
    parse_point([timestamp, bpm])
  end

  defp parse_point(%{"time" => timestamp, "value" => bpm}) do
    parse_point([timestamp, bpm])
  end

  defp parse_point(_), do: :skip

  defp cast_timestamp(timestamp) when is_integer(timestamp) do
    cond do
      timestamp > 9_999_999_999 ->
        DateTime.from_unix(timestamp, :millisecond)

      true ->
        DateTime.from_unix(timestamp)
    end
  end

  defp cast_timestamp(timestamp) when is_binary(timestamp) do
    with {:ok, dt, _offset} <- DateTime.from_iso8601(timestamp) do
      {:ok, dt}
    else
      _ ->
        case Integer.parse(timestamp) do
          {int, ""} ->
            cast_timestamp(int)

          _ ->
            with {:ok, naive} <- NaiveDateTime.from_iso8601(timestamp) do
              DateTime.from_naive(naive, "Etc/UTC")
            end
        end
    end
  end

  defp cast_timestamp(_), do: {:error, :invalid_timestamp}

  defp normalize_source(source) when is_binary(source), do: source
  defp normalize_source(_), do: nil

  defp fetch_first(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} -> value
        :error -> nil
      end
    end)
  end
end
