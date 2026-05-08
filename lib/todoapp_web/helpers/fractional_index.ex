defmodule Todoapp.Helpers.FractionalIndex do
  @base62_chars [
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z"
  ]

  @base_size length(@base62_chars)
  @max_idx @base_size - 1
  @mid_idx div(@base_size, 2)

  @char_to_idx @base62_chars
               |> Enum.with_index()
               |> Map.new()

  @idx_to_char @base62_chars
               |> Enum.with_index()
               |> Map.new(fn {c, i} -> {i, c} end)

  @mid_char Map.fetch!(@idx_to_char, @mid_idx)

  def generate_position(nil, nil), do: {:ok, @mid_char}

  def generate_position(prev, next) when is_binary(prev) and is_binary(next) do
    cond do
      prev == next -> {:error, :no_space}
      prev > next -> {:error, :invalid_range}
      true -> do_generate(to_indices(prev), to_indices(next))
    end
  end

  def generate_position(nil, next) when is_binary(next) do
    case gen_below(to_indices(next)) do
      {:ok, idx} -> {:ok, from_indices(idx)}
      err -> err
    end
  end

  def generate_position(prev, nil) when is_binary(prev) do
    case gen_above(to_indices(prev)) do
      {:ok, idx} -> {:ok, from_indices(idx)}
      err -> err
    end
  end

  defp do_generate(prev_idx, next_idx) do
    case midpoint(prev_idx, next_idx) do
      {:ok, idx} -> {:ok, from_indices(idx)}
      err -> err
    end
  end

  # Find a list of indices strictly between `a` and `b`.
  # Pre: a < b lexicographically (caller checks).
  defp midpoint([], []), do: {:error, :no_space}
  defp midpoint([], b), do: gen_below(b)
  defp midpoint(a, []), do: gen_above(a)

  defp midpoint([a0 | a_rest], [b0 | b_rest]) do
    cond do
      a0 == b0 ->
        # Shared leading char; recurse into the suffix.
        with {:ok, tail} <- midpoint(a_rest, b_rest), do: {:ok, [a0 | tail]}

      b0 - a0 >= 2 ->
        # There's at least one index strictly between a0 and b0.
        # Picking div(a0+b0, 2) is always > a0 and < b0, and > 0
        # (since b0 >= 2, so a0 + b0 >= 2 and div >= 1).
        {:ok, [div(a0 + b0, 2)]}

      b0 - a0 == 1 ->
        # No char fits between a0 and b0, so reuse a0 and pick a tail
        # that's strictly greater than a_rest.
        with {:ok, tail} <- gen_above(a_rest), do: {:ok, [a0 | tail]}

      true ->
        # a0 > b0 — caller violated the precondition.
        {:error, :invalid_range}
    end
  end

  # Any list of indices strictly less than `b`, never ending in 0.
  defp gen_below([]), do: {:error, :no_space}

  defp gen_below([b0 | b_rest]) do
    cond do
      b0 >= 2 ->
        # Pick something in (0, b0). div(b0, 2) >= 1, so it doesn't
        # violate the trailing-min invariant.
        {:ok, [div(b0, 2)]}

      b0 == 1 ->
        # Anything starting with "0" is < "1...". Use "0" + mid char so
        # we don't end in min and we keep both-side headroom.
        {:ok, [0, @mid_idx]}

      b0 == 0 ->
        # b starts with "0"; we must too, then recurse into the tail.
        # b_rest is non-empty for well-formed inputs (never end in 0);
        # if it is empty, gen_below([]) returns :no_space.
        with {:ok, tail} <- gen_below(b_rest), do: {:ok, [0 | tail]}
    end
  end

  # Any list of indices strictly greater than `a`, never ending in 0.
  # `a` may be empty, meaning "any non-empty position".
  defp gen_above([]), do: {:ok, [@mid_idx]}

  defp gen_above([a0 | a_rest]) do
    cond do
      a0 <= @max_idx - 2 ->
        # Pick a char midway between a0+1 and max_idx. Result is > a0
        # and != 0 (since a0 + max_idx + 1 >= 1).
        {:ok, [div(a0 + @max_idx + 1, 2)]}

      a_rest == [] ->
        # a0 is "y" or "z" with nothing after it; extend with mid char.
        # The result starts with a0 then a non-min char, so it's > a
        # by the prefix rule and doesn't end in min.
        {:ok, [a0, @mid_idx]}

      true ->
        # a0 is "y" or "z" with more chars after; reuse a0 and recurse
        # to grow something > a_rest.
        with {:ok, tail} <- gen_above(a_rest), do: {:ok, [a0 | tail]}
    end
  end

  defp to_indices(string) do
    string
    |> String.graphemes()
    |> Enum.map(fn c ->
      case Map.fetch(@char_to_idx, c) do
        {:ok, idx} -> idx
        :error -> raise ArgumentError, "invalid base62 char: #{inspect(c)}"
      end
    end)
  end

  defp from_indices(indices) do
    indices
    |> Enum.map(&Map.fetch!(@idx_to_char, &1))
    |> IO.iodata_to_binary()
  end
end
