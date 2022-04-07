defmodule DomainNameOperator.Utils do
  @doc """
  Convert a list to a `String`, suitable for printing

  Will raise a `String.chars` error if can't coerce part to a `String`

  `mask_keys` is used to mask the values in any keys that are in maps in the `list`
  """
  @spec list_to_string(list :: list() | String.Chars.t(), mask_keys :: list(binary())) :: binary()
  def list_to_string(list, mask_keys \\ []) do
    list
    |> Enum.map(fn val ->
      case val do
        %{} -> map_to_string(val, mask_keys)
        l when is_list(l) -> list_to_string(l, mask_keys)
        t when is_tuple(t) -> tuple_to_string(t, mask_keys)
        _ -> Kernel.to_string(val)
      end
    end)
    |> Enum.join(", ")
  end

  @doc """
  Convert a tuple to a `String`, suitable for printing

  Will raise a `String.chars` error if can't coerce part to a `String`

  `mask_keys` is used to mask the values in any keys that are in maps in the `tuple`
  """
  @spec tuple_to_string(tuple :: tuple() | String.Chars.t(), mask_keys :: list(binary())) :: binary()
  def tuple_to_string(tuple, mask_keys \\ []) do
    tuple
    |> Tuple.to_list()
    |> list_to_string(mask_keys)
  end

    @doc """
  Convert a map to a `String`, suitable for printing.

  Optionally pass a list of keys to mask.

  ## Examples

      iex> map_to_string(%{michael: "knight"})
      "michael: 'knight'"

      iex> map_to_string(%{michael: "knight", kitt: "karr"})
      "kitt: 'karr', michael: 'knight'"

      iex> map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt])
      "kitt: '****', michael: 'knight'"

      iex> map_to_string(%{michael: "knight", kitt: "karr"}, [:kitt, :michael])
      "kitt: '****', michael: '******'"

      iex> map_to_string(%{"michael" => "knight", "kitt" => "karr", "carr" => "hart"}, ["kitt", "michael"])
      "carr: 'hart', kitt: '****', michael: '******'"

  """
  @spec map_to_string(map :: map() | String.Chars.t(), mask_keys :: list(binary())) :: binary()
  def map_to_string(map, mask_keys \\ [])

  def map_to_string(%{} = map, mask_keys) do
    Map.to_list(map)
    |> Enum.reverse()
    |> Enum.map(fn {key, val} ->
      case val do
        %{} -> {key, map_to_string(val, mask_keys)}
        l when is_list(l) -> {key, list_to_string(l, mask_keys)}
        t when is_tuple(t) -> {key, tuple_to_string(t, mask_keys)}
        _ -> {key, val}
      end
    end)
    |> Enum.map(fn {key, val} ->
      case key in list_to_strings_and_atoms(mask_keys) do
        true -> {key, mask_str(val)}
        _ -> {key, val}
      end
    end)
    |> Enum.map(fn {key, val} -> "#{key}: '#{val}'" end)
    |> Enum.join(", ")
  end

  def map_to_string(not_a_map, _mask_keys), do: Kernel.to_string(not_a_map)

  @doc ~S"""
  Convert the value, map, or list to a string, suitable for printing or storing.

  If the value is not a map or list, it must be a type that implements the
  `String.Chars` protocol, otherwise this will fail.

  The reason to offer this util function rather than implementing `String.Chars`
  for maps and lists is that we want to make sure that we never accidentally
  convert those to a string.  This conversion is somewhat destructive and is
  irreversable, so it should only be done intentionally.
  """
  @spec to_string(input :: map() | list() | String.Chars.t(), mask_keys :: list(binary())) :: binary()
  def to_string(value, mask_keys \\ [])
  def to_string(%{} = map, mask_keys), do: map_to_string(map, mask_keys)
  def to_string(list, mask_keys) when is_list(list), do: list_to_string(list, mask_keys)
  def to_string(tuple, mask_keys) when is_tuple(tuple), do: tuple_to_string(tuple, mask_keys)
  def to_string(value, _mask_keys), do: Kernel.to_string(value)

  @doc """
  Takes a list of strings or atoms and returns a list with string and atoms.

  ## Examples

      iex> list_to_strings_and_atoms([:circle])
      [:circle, "circle"]

      iex> list_to_strings_and_atoms([:circle, :square])
      [:square, "square", :circle, "circle"]

      iex> list_to_strings_and_atoms(["circle", "square"])
      ["square", :square, "circle", :circle]
  """
  def list_to_strings_and_atoms(list) do
    Enum.reduce(list, [], fn l, acc -> [l | [atom_or_string_to_string_or_atom(l) | acc]] end)
  end

  @doc ~S"""
  Replaces the caracters in `str` with asterisks `"*"`, thus "masking" the value.

  If argument is `nil` nothing will change `nil` will be returned.
  If argument is not a `binary()`, it will be coerced to a binary then masked.
  """
  def mask_str(nil), do: nil
  def mask_str(str) when is_binary(str), do: String.replace(str, ~r/./, "*")
  def mask_str(val), do: Kernel.inspect(val) |> mask_str()


  defp atom_or_string_to_string_or_atom(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp atom_or_string_to_string_or_atom(string) when is_binary(string) do
    String.to_atom(string)
  end
end

defmodule DomainNameOperator.Utils.FromEnv do
  def log_str(env, :mfa), do: "[#{mfa_str(env)}]"
  def log_str(env, :func_only), do: "[#{func_str(env)}]"
  def log_str(env), do: log_str(env, :mfa)

  def mfa_str(env), do: mod_str(env) <> "." <> func_str(env)

  def func_str({func, arity}), do: "##{func}/#{arity}"
  def func_str(env), do: func_str(env.function)

  def mod_str(env), do: Kernel.to_string(env.module)
end

defmodule DomainNameOperator.Utils.Logger do
  alias DomainNameOperator.Utils.LoggerColor

  require Logger

  def emergency(msg), do: Logger.emergency(msg, ansi_color: LoggerColor.red())
  def alert(msg), do: Logger.alert(msg, ansi_color: LoggerColor.red())
  def critical(msg), do: Logger.critical(msg, ansi_color: LoggerColor.red())
  def error(msg), do: Logger.error(msg, ansi_color: LoggerColor.red())
  def warning(msg), do: Logger.warning(msg, ansi_color: LoggerColor.yellow())
  def notice(msg), do: Logger.notice(msg, ansi_color: LoggerColor.yellow())
  def info(msg), do: Logger.info(msg, ansi_color: LoggerColor.green())
  def debug(msg), do: Logger.debug(msg, ansi_color: LoggerColor.cyan())
end

defmodule DomainNameOperator.Utils.LoggerColor do
  def green, do: :green
  def black, do: :black
  def red, do: :red
  def yellow, do: :yellow
  def blue, do: :blue
  def cyan, do: :cyan
  def white, do: :white
end
