defmodule Nimrag.OAuth1Token do
  @moduledoc """
  See `Nimrag.Credentials` for more details on how to obtain auth tokens.
  """
  @type t() :: %__MODULE__{
          oauth_token: nil | String.t(),
          oauth_token_secret: nil | String.t(),
          mfa_token: nil | String.t(),
          domain: nil | String.t(),
          expires_at: nil | DateTime.t()
        }
  @derive Jason.Encoder
  defstruct ~w(oauth_token oauth_token_secret mfa_token domain expires_at)a

  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: nil}), do: true

  def expired?(%__MODULE__{expires_at: expires_at}),
    do: DateTime.before?(expires_at, DateTime.utc_now())
end

defimpl Inspect, for: Nimrag.OAuth1Token do
  alias Nimrag.OAuth1Token
  import Inspect.Algebra

  def inspect(
        %OAuth1Token{oauth_token: oauth_token, mfa_token: mfa_token} = token,
        opts
      ) do
    mask = fn
      nil -> nil
      "" -> ""
      value -> String.slice(value, 0, 5) <> "..."
    end

    {details_doc, _opts} =
      Inspect.Map.inspect(
        %{
          oauth_token: mask.(oauth_token),
          mfa_token: mask.(mfa_token),
          expired?: OAuth1Token.expired?(token),
          expires_at: token.expires_at
        },
        opts
      )

    "#Nimrag.OAuth1Token<"
    |> string()
    |> concat(details_doc)
    |> concat(string(">"))
  end
end
