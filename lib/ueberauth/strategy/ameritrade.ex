defmodule Ueberauth.Strategy.Ameritrade do
  @moduledoc """
  Ameritrade Strategy for Überauth.
  """

  use Ueberauth.Strategy, uid_field: :userId, default_scope: "identify"

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  alias Ueberauth.Strategy.Ameritrade.OAuth

  @doc """
  Handles initial request for Ameritrade authentication.
  """
  def handle_request!(conn) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Ameritrade.OAuth)

    opts = options_from_conn(conn)

    redirect!(conn, OAuth.authorize_url!(opts))
  end

  @doc false
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]

    token = OAuth.get_token!([code: code], opts)

    if token.access_token == nil do
      err = token.other_params[:error]
      desc = token.other_params[:error_description]
      set_errors!(conn, [error(err, desc)])
    else
      conn
      |> store_token(token)
      |> fetch_user(token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:ameritrade_token, nil)
    |> put_private(:ameritrade_user, nil)
  end

  # Store the token for later use.
  @doc false
  defp store_token(conn, token) do
    put_private(conn, :ameritrade_token, token)
  end


  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.ameritrade_user

    %Info{
      nickname: user["userId"]
    }
  end

  @doc """
  Includes the credentials from the Ameritrade response.
  """
  def credentials(conn) do
    token = conn.private.ameritrade_token
    scopes = split_scopes(token)

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      token: token.access_token,
      refresh_token: token.refresh_token,
      scopes: scopes,
      other: %{
        refresh_token_expires_in: token.other_params["refresh_token_expires_in"]
      }
    }
  end

  @doc """
  Stores the raw information (the token and user)
  obtained from the Ameritrade callback.
  """
  def extra(conn) do
    %{
      ameritrade_token: :token,
      ameritrade_user: :user,
    }
    |> Enum.filter(fn {original_key, _} ->
      Map.has_key?(conn.private, original_key)
    end)
    |> Enum.map(fn {original_key, mapped_key} ->
      {mapped_key, Map.fetch!(conn.private, original_key)}
    end)
    |> Map.new()
    |> (&%Extra{raw_info: &1}).()
  end

    @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string

    conn.private.ameritrade_user[uid_field]
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  defp options_from_conn(conn) do
    base_options = [redirect_uri: callback_url(conn)]
    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:client_secret]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end

    defp split_scopes(token) do
    (token.other_params["scope"] || "")
    |> String.split(" ")
  end

  defp fetch_user(conn, token) do
    path = "https://api.tdameritrade.com/v1/userprincipals"
    resp = Ueberauth.Strategy.Ameritrade.OAuth.get(token, path)

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->

        put_private(conn, :ameritrade_user, user)

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end
end
