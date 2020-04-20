defmodule Freshness.Response do
  @type t() :: %__MODULE__{
          data: iolist(),
          status: non_neg_integer(),
          headers: list({String.t(), binary()})
        }

  defstruct [
    :headers,
    :status,
    data: []
  ]

  @spec generate_response([any]) :: {:error, any} | {:ok, t()}
  def generate_response(stream) do
    stream
    |> List.flatten()
    |> Enum.reduce_while(%__MODULE__{}, fn
      {:status, _ref, status}, acc -> {:cont, %{acc | status: status}}
      {:headers, _ref, headers}, acc -> {:cont, %{acc | headers: headers}}
      {:data, _ref, data}, acc -> {:cont, %{acc | data: [data | acc.data]}}
      {:error, _ref, reason}, _ -> {:halt, {:error, reason}}
      _, acc -> {:cont, acc}
    end)
    |> case do
      {:error, _} = error -> error
      response -> {:ok, response}
    end
  end
end
