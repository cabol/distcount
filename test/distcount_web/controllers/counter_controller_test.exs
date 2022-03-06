defmodule DistcountWeb.CounterControllerTest do
  use DistcountWeb.ConnCase

  import Distcount.TestUtils

  alias Distcount.Counters

  @incr_attrs %{
    key: "some key",
    value: 10
  }

  @invalid_attrs %{key: nil, value: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/v1/increment" do
    test "renders counter log record when data is valid", %{conn: conn} do
      conn = post(conn, Routes.counter_log_path(conn, :incr), @incr_attrs)

      assert %{"key" => key} = json_response(conn, 202)["data"]

      wait_until(fn ->
        assert Counters.get_counter_value(key) == 10
      end)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.counter_log_path(conn, :incr), @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
