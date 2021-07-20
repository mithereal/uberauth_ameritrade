defmodule Ueberauth.Strategy.Ameritrade.OAuth do
  @moduledoc """
  OAuth2 for Ameritrade.

  Add `client_id`  to your configuration:

  config :ueberauth, Ueberauth.Strategy.Ameritrade.OAuth,
    client_id: System.get_env("AMERITRADE_KEY"),
  """

  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://auth.tdameritrade.com",
    authorize_url: "https://auth.tdameritrade.com/auth",
    token_url: "https://api.tdameritrade.com/v1/oauth2/token"
  ]

  @doc """
  Construct a client for requests to Ameritrade.
  This will be setup automatically for you in `Ueberauth.Strategy.Ameritrade`.
  These options are only useful for usage outside the normal callback phase
  of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Ameritrade.OAuth)

    client_id = [client_id: config[:client_id] <> "@AMER.OAUTHAP"]

    opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)
      |> Keyword.merge(client_id)

    json_library = Ueberauth.json_library()

    OAuth2.Client.new(opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth.
  No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    client(token: token)
    |> put_param("client_secret", client().client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_token(params \\ [], opts \\ []) do

    code = params[:code]

    code = URI.decode(code)

    client =
      opts
      |> client
       |> OAuth2.Client.get_token!(code: code)


  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

end