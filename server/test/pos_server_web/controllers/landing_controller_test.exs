defmodule PosServerWeb.LandingControllerTest do
  use PosServerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Designs"
  end

  test "GET /privacy-policy is public", %{conn: conn} do
    conn = get(conn, ~p"/privacy-policy")
    assert html_response(conn, 200) =~ "Política de privacidad"
  end

  test "GET /terms-of-service is public", %{conn: conn} do
    conn = get(conn, ~p"/terms-of-service")
    assert html_response(conn, 200) =~ "Términos de servicio"
  end
end
