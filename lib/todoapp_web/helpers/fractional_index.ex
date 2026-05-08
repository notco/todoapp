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
  @min_char "0"
  @max_char "z"

  @doc """
  Generate a position between two existing positions.

  ## Parameters
  - prev_position: Position of the task before the insertion point (nil if inserting at beginning)
  - next_position: Position of the task after the insertion point (nil if inserting at end)

  ## Returns
  - {:ok, position} - New position string
  - {:error, :no_space} - No available space between positions

  ## Examples
      iex> generate_position("a", "b")
      {:ok, "aV"}

      iex> generate_position("a", "c")
      {:ok, "b"}

      iex> generate_position("aV", "b")
      {:ok, "aVZ"}
  """
  def generate_position(prev_position, next_position) do
    case find_position_between(prev_position, next_position) do
      {:ok, pos} -> {:ok, pos}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp find_position_between(nil, nil) do
    # No tasks exist, start with middle position
    middle_char = Enum.at(@base62_chars, div(length(@base62_chars), 2))
    {:ok, List.to_string([middle_char])}
  end

  defp find_position_between(nil, next_pos) do
    # Inserting at beginning - generate something smaller than next_pos
    case generate_smaller_position(next_pos, 2) do
      {:ok, pos} -> {:ok, pos}
      {:error, _} -> {:error, :no_space}
    end
  end

  defp find_position_between(prev_pos, nil) do
    # Inserting at end - generate something larger than prev_pos
    case generate_larger_position(prev_pos, 2) do
      {:ok, pos} -> {:ok, pos}
      {:error, _} -> {:error, :no_space}
    end
  end

  defp find_position_between(prev_pos, next_pos) do
    # Try simple character averaging first
    case try_character_average(prev_pos, next_pos) do
      {:ok, pos} ->
        {:ok, pos}

      {:error, _} ->
        # Fall back to extension approach
        {:error, :no_space}
    end
  end

  defp try_character_average(prev_pos, next_pos) do
    # Find the first position where characters differ
    case find_divergence_point(prev_pos, next_pos) do
      {:ok, prefix, "", next_char} ->
        generate_smaller_position(next_pos, 1)

      {:ok, prefix, prev_char, ""} ->
        generate_larger_position(prev_pos, 1)

      {:ok, prefix, prev_char, next_char} ->
        # Generate middle character between prev_char and next_char

        prev_index = find_char_index(prev_char)
        next_index = find_char_index(next_char)

        index_diff = next_index - prev_index

        if index_diff > 1 do
          # There's space for a character between them
          mid_index = div(prev_index + next_index, 2)
          mid_char = Enum.at(@base62_chars, mid_index)
          {:ok, prefix <> List.to_string([mid_char])}
        else
          generate_larger_position(prev_pos, index_diff)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_divergence_point(prev_pos, next_pos) do
    find_first_difference(prev_pos, next_pos, "", 0)
  end

  defp find_first_difference(prev_pos, next_pos, prefix, index) do
    cond do
      prev_pos == "" and next_pos == "" ->
        # Both strings are identical
        {:error, :identical_strings}

      prev_pos == "" ->
        # prev_pos ended, next_pos continues
        {:ok, prefix, "", String.first(next_pos)}

      next_pos == "" ->
        # next_pos ended, prev_pos continues
        {:ok, prefix, String.first(prev_pos), ""}

      String.first(prev_pos) == String.first(next_pos) ->
        # Characters match, continue with next characters
        new_prefix = prefix <> String.first(prev_pos)
        new_prev = String.slice(prev_pos, 1, String.length(prev_pos) - 1)
        new_next = String.slice(next_pos, 1, String.length(next_pos) - 1)
        find_first_difference(new_prev, new_next, new_prefix, index + 1)

      true ->
        # Found divergence point
        {:ok, prefix, String.first(prev_pos), String.first(next_pos)}
    end
  end

  defp generate_smaller_position(next_pos, index_diff) do
    # Generate a position smaller than next_pos
    last_char = String.last(next_pos)
    char_index = find_char_index(last_char)

    if char_index != @min_char and index_diff > 1 do
      # Use a smaller character
      smaller_char = Enum.at(@base62_chars, char_index - 1)
      smaller_pos = String.slice(next_pos, 0..-2//1) <> smaller_char
      {:ok, smaller_pos}
    else
      # First character is already maximum, try extending
      {:ok, next_pos <> List.to_string([@max_char])}
    end
  end

  defp generate_larger_position(prev_pos, index_diff) do
    # Generate a position larger than prev_pos
    last_char = String.last(prev_pos)
    char_index = find_char_index(last_char)

    if char_index != @max_char and index_diff > 1 do
      # Use a larger character
      larger_char = Enum.at(@base62_chars, char_index + 1)
      larger_pos = String.slice(prev_pos, 0..-2//1) <> larger_char
      {:ok, larger_pos}
    else
      # First character is already maximum, try extending
      {:ok, prev_pos <> List.to_string([@min_char])}
    end
  end

  defp find_char_index(char) do
    case Enum.find_index(@base62_chars, fn c -> c == char end) do
      # Default to first character if not found
      index -> index
    end
  end
end
