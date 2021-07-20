defmodule Ueberauth.Strategy.Ameritrade do
  @moduledoc """
  Ameritrade Strategy for Überauth.
  """

  use Ueberauth.Strategy, uid_field: :id, default_scope: "identify"

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for Ameritrade authentication.
  """
  def handle_request!(conn) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Ameritrade.OAuth)

    opts = options_from_conn(conn)

    redirect!(conn, Ueberauth.Strategy.Ameritrade.OAuth.authorize_url!(opts))
  end

  @doc false
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]
    token = Ueberauth.Strategy.Ameritrade.OAuth.get_token([code: code], opts)

    if token.access_token == nil do
      err = token.other_params["error"]
      desc = token.other_params["error_description"]
      set_errors!(conn, [error(err, desc)])
    else
      conn
      |> store_token(token)
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
    |> put_private(:ameritrade_email, nil)
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
    email = conn.private.ameritrade_email

    %Info{
      email: email
    }
  end

  @doc """
  Includes the credentials from the Ameritrade response.
  """
  def credentials(conn) do
    token = conn.private.ameritrade_token

    IO.inspect(token, label: "credentials")

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      refresh_token: token.refresh_token,
      token: token.access_token
    }
  end

  @doc """
  Stores the raw information (including the token, user, connections and guilds)
  obtained from the Ameritrade callback.
  """
  def extra(conn) do
    %{
      ameritrade_token: :token,
      ameritrade_uid: :ameritrade_uid
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

    conn.private.ameritrade_uid
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  defp with_optional_param_or_default(opts, key, conn) do
    cond do
      value = conn.params[to_string(key)] ->
        Keyword.put(opts, key, value)

      default_opt = option(conn, key) ->
        Keyword.put(opts, key, default_opt)

      true ->
        opts
    end
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
  end