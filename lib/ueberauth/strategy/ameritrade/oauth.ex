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
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_token(params \\ [], opts \\ []) do

    code = params[:code]

    code = URI.decode(code)

    client =
      opts
      |> client
       |> get_token!(code: code)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end


  def get_token(client, params, headers) do
    {code, params} = Keyword.pop(params, :code, client.params["code"])

    unless code do
      raise OAuth2.Error, reason: "Missing required key `code` for `#{inspect(__MODULE__)}`"
    end

    client
    |> put_param(:code, code)
    |> put_param(:grant_type, "authorization_code")
    |> put_param(:client_id, client.client_id)
    |> put_param(:redirect_uri, client.redirect_uri)
    |> merge_params(params)
    |> basic_auth()
    |> put_headers(headers)
  end

   def get_token!(client, params \\ [], headers \\ [], opts \\ []) do
    case get_token(client, params, headers, opts) do
      {:ok, client} ->
        client

      {:error, %Response{status_code: code, headers: headers, body: body}} ->
        raise %Error{
          reason: """
          Server responded with status: #{code}

          Headers:

          #{Enum.reduce(headers, "", fn {k, v}, acc -> acc <> "#{k}: #{v}\n" end)}
          Body:

          #{inspect(body)}
          """
        }

      {:error, error} ->
        raise error
    end
  end

    def basic_auth(%OAuth2.Client{client_id: id, client_secret: secret} = client) do
    put_header(client, "authorization", "Basic " <> Base.encode64(id))
  end

end