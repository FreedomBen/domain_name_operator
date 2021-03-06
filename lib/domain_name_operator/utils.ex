defmodule DomainNameOperator.Utils do
  @doc ~S"""
  Using either `key` or `extract_func`, extract the specified thing.

  Alias is `process()` and `transform()`

  This is very useful for converting some value into another in a pipeline,
  such as unwrapping a structure or transforming it.  It's essentially like
  `Enum.map/2` but only operates on a single object rather than an `Enumerable`

  Example:

  ```
  some_function_returns_a_map()
  |> DomainNameOperator.Utils.extract(:data)  # extract the 'data' key from map
  |> Enum.map(...)

  get_user()
  |> DomainNameOperator.Utils.extract(:age)
  |> handle_age()

  get_user()
  |> DomainNameOperator.Utils.extract(%{name: "Jeb", age: 37}, fn {:ok, user} -> user)
  |> extract()
  ```
  ## iex examples:

    iex> DomainNameOperator.Utils.extract(%{name: "Jeb", age: 37}, :age)
    37

    iex> DomainNameOperator.Utils.extract(%{name: "Jeb", age: 37}, fn arg -> arg[:age] * 2 end)
    74
  """
  @spec extract(
          Access.t() | List.t() | Tuple.t() | any(),
          integer() | String.t() | (... -> any())
        ) :: any()
  def extract(list, key) when is_list(list) and is_integer(key) do
    Enum.at(list, key)
  end

  def extract(tuple, key) when is_tuple(tuple) and is_integer(key) do
    elem(tuple, key)
  end

  def extract(access, key) when is_atom(key) or is_binary(key) do
    access[key]
  end

  def extract(anything, extract_func) do
    extract_func.(anything)
  end

  @spec process(
          Access.t() | List.t() | Tuple.t() | any(),
          integer() | String.t() | (... -> any())
        ) :: any()
  def process(thing, arg), do: extract(thing, arg)

  @spec transform(
          Access.t() | List.t() | Tuple.t() | any(),
          integer() | String.t() | (... -> any())
        ) :: any()
  def transform(thing, arg), do: extract(thing, arg)

  @doc ~S"""
  Macro that makes a function public in test, private in non-test

  See:  https://stackoverflow.com/a/47598190/2062384
  """
  defmacro defp_testable(head, body \\ nil) do
    if Mix.env() == :test do
      quote do
        def unquote(head) do
          unquote(body[:do])
        end
      end
    else
      quote do
        defp unquote(head) do
          unquote(body[:do])
        end
      end
    end
  end

  @doc ~S"""
  Easy drop-in to a pipe to inspect the return value of the previous function.

  ## Examples

      conn
      |> put_status(:not_found)
      |> put_view(DomainNameOperatorWeb.ErrorView)
      |> render(:"404")
      |> pry_pipe()

  ## Alternatives

  You may also wish to consider using `IO.inspect/3` in pipelines.  `IO.inspect/3`
  will print and return the value unchanged.  Example:

      conn
      |> put_status(:not_found)
      |> IO.inspect(label: "after status")
      |> render(:"404")

  """
  def pry_pipe(retval, arg1 \\ nil, arg2 \\ nil, arg3 \\ nil, arg4 \\ nil) do
    require IEx
    IEx.pry()
    retval
  end

  @doc ~S"""
  Retrieve syntax colors for embedding into `:syntax_colors` of `Inspect.Opts`

  You probably don't want this directly.  You probably want `inspect_format`
  """
  def inspect_syntax_colors do
    [
      number: :yellow,
      atom: :cyan,
      string: :green,
      boolean: :magenta,
      nil: :magenta
    ]
  end

  @doc ~S"""
  Get `Inspect.Opts` for `Kernel.inspect` or `IO.inspect`

  If `opaque_struct` is false, then structs will be printed as `Map`s, which
  allows you to see any opaque fields they might have set

  `limit` is the max number of stuff printed out.  Can be an integer or `:infinity`
  """
  def inspect_format(opaque_struct \\ true, limit \\ 50) do
    [
      structs: opaque_struct,
      limit: limit,
      syntax_colors: inspect_syntax_colors(),
      width: 80
    ]
  end

  @doc ~S"""
  Runs `IO.inspect/2` with pretty printing, colors, and unlimited size.

  If `opaque_struct` is false, then structs will be printed as `Map`s, which
  allows you to see any opaque fields they might have set
  """
  def inspect(val, opaque_struct \\ true, limit \\ 50) do
    Kernel.inspect(val, inspect_format(opaque_struct, limit))
  end

  @doc ~S"""
  Convert a map with `String` keys into a map with `Atom` keys.

  ## Examples

      iex> DomainNameOperator.Utils.map_string_keys_to_atoms(%{"one" => "one", "two" => "two"})
      %{one: "one", two: "two"}m

  """
  def map_string_keys_to_atoms(map) do
    for {key, val} <- map, into: %{} do
      {String.to_atom(key), val}
    end
  end

  @doc ~S"""
  Convert a map with `String` keys into a map with `Atom` keys.

  ## Examples

      iex> DomainNameOperator.Utils.map_atom_keys_to_strings(%{one: "one", two: "two"})
      %{"one" => "one", "two" => "two"}

  """
  def map_atom_keys_to_strings(map) do
    for {key, val} <- map, into: %{} do
      {Atom.to_string(key), val}
    end
  end

  @doc ~S"""
  Converts a struct to a regular map by deleting the `:__meta__` key

  ## Examples

      DomainNameOperator.Utils.struct_to_map(%Something{hello: "world"})
      %{hello: "world"}

  """
  def struct_to_map(struct, mask_keys \\ []) do
    Map.from_struct(struct)
    |> Map.delete(:__meta__)
    |> mask_map_key_values(mask_keys)
  end

  @doc ~S"""
  Takes a map and a list of keys whose values should be masked

  ## Examples

      iex> DomainNameOperator.Utils.mask_map_key_values(%{name: "Ben, title: "Lord"}, [:title])
      %{name: "Ben", title: "****"}

      iex> DomainNameOperator.Utils.mask_map_key_values(%{name: "Ben, age: 39}, [:age])
      %{name: "Ben", age: "**"}
  """
  def mask_map_key_values(map, mask_keys) do
    map
    |> Enum.map(fn {key, val} ->
      case key in list_to_strings_and_atoms(mask_keys) do
        true -> {key, mask_str(val)}
        _ -> {key, val}
      end
    end)
    |> Enum.into(%{})
  end

  @doc ~S"""
  Quick regex check to see if the supplied `string` is a valid UUID

  Check is done by simple regular expression and is not overly sophisticated.

  Return true || false

  ## Examples

      iex> DomainNameOperator.Utils.is_uuid?(nil)
      false
      iex> DomainNameOperator.Utils.is_uuid?("hello world")
      false
      iex> DomainNameOperator.Utils.is_uuid?("4c2fd8d3-a6e3-4e4b-a2ce-3f21456eeb85")
      true

  """
  def is_uuid?(nil), do: false

  def is_uuid?(string),
    do:
      string =~ ~r/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

  def is_uuid_or_nil?(nil), do: true
  def is_uuid_or_nil?(string), do: is_uuid?(string)

  # def nil_or_empty?(nil), do: true
  # def nil_or_empty?(str) when is_string(str), do: "" == str |> String.trim()

  @doc """
  Checks if the passed item is nil or empty string.

  The param will be passed to `Kernel.to_string()`
  and then `String.trim()` and checked for empty string

  ## Examples

      iex> DomainNameOperator.Utils.nil_or_empty?("hello")
      false
      iex> DomainNameOperator.Utils.nil_or_empty?("")
      true
      iex> DomainNameOperator.Utils.nil_or_empty?(nil)
      true

  """
  def nil_or_empty?(str_or_nil) do
    "" == str_or_nil |> Kernel.to_string() |> String.trim()
  end

  def not_nil_or_empty?(str_or_nil), do: not nil_or_empty?(str_or_nil)

  @doc """
  if `value` (value of the argument) is nil, this will raise `DomainNameOperator.CantBeNil`

  `argn` (name of the argument) will be passed to allow for more helpful error
  messages that tell you the name of the variable that was `nil`

  ## Examples

      iex> DomainNameOperator.Utils.raise_if_nil!("somevar", "someval")
      "someval"
      iex> DomainNameOperator.Utils.raise_if_nil!("somevar", nil)
      ** (DomainNameOperator.CantBeNil) variable 'somevar' was nil but cannot be
          (domain_name_operator 0.1.0) lib/domain_name_operator/utils.ex:135: DomainNameOperator.Utils.raise_if_nil!/2

  """
  def raise_if_nil!(varname, value) do
    case is_nil(value) do
      true -> raise DomainNameOperator.CantBeNil, varname: varname
      false -> value
    end
  end

  @doc """
  if `value` (value of the argument) is nil, this will raise `DomainNameOperator.CantBeNil`

  `argn` (name of the argument) will be passed to allow for more helpful error
  messages that tell you the name of the variable that was `nil`

  ## Examples

      iex> DomainNameOperator.Utils.raise_if_nil!("someval")
      "someval"
      iex> DomainNameOperator.Utils.raise_if_nil!(nil)
      ** (DomainNameOperator.CantBeNil) variable 'somevar' was nil but cannot be
          (domain_name_operator 0.1.0) lib/domain_name_operator/utils.ex:142: DomainNameOperator.Utils.raise_if_nil!/1

  """
  def raise_if_nil!(value) do
    case is_nil(value) do
      true -> raise DomainNameOperator.CantBeNil
      false -> value
    end
  end

  @doc ~S"""
  Replaces the caracters in `str` with asterisks `"*"`, thus "masking" the value.

  If argument is `nil` nothing will change `nil` will be returned.
  If argument is not a `binary()`, it will be coerced to a binary then masked.
  """
  def mask_str(nil), do: nil
  def mask_str(str) when is_binary(str), do: String.replace(str, ~r/./, "*")
  def mask_str(val), do: Kernel.inspect(val) |> mask_str()

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
  @type tuple_key_value :: binary() | atom()
  @spec tuple_to_string(
          tuple :: {tuple_key_value, tuple_key_value} | String.Chars.t(),
          mask_keys :: list(binary())
        ) ::
          binary()
  def tuple_to_string(tuple, mask_keys \\ [])

  def tuple_to_string({key, value}, mask_keys) do
    # mask value if key is supposed to be masked.  Otherwise pass on
    cond do
      key in list_to_strings_and_atoms(mask_keys) -> {key, mask_str(value)}
      true -> {key, value}
    end
    |> Tuple.to_list()
    |> list_to_string(mask_keys)
  end

  @spec tuple_to_string(tuple :: tuple() | String.Chars.t(), mask_keys :: list(binary())) ::
          binary()
  def tuple_to_string(tuple, mask_keys) do
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
  @spec to_string(input :: map() | list() | String.Chars.t(), mask_keys :: list(binary())) ::
          binary()
  def to_string(value, mask_keys \\ [])
  def to_string(%{} = map, mask_keys), do: map_to_string(map, mask_keys)
  def to_string(list, mask_keys) when is_list(list), do: list_to_string(list, mask_keys)
  def to_string(tuple, mask_keys) when is_tuple(tuple), do: tuple_to_string(tuple, mask_keys)
  def to_string(value, _mask_keys), do: Kernel.to_string(value)

  defp atom_or_string_to_string_or_atom(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp atom_or_string_to_string_or_atom(string) when is_binary(string) do
    String.to_atom(string)
  end

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

  def trunc_str(str, length \\ 255), do: String.slice(str, 0, length)

  @doc ~S"""
  If `val` is explicitly (and therefore unambiguously) true, then returns `false`.  Otherwise `true`

  Explicitly true values are case-insensitive, "t", "true", "yes", "y"
  """
  def explicitly_true?(val) when is_binary(val), do: String.downcase(val) in ~w[t true yes y]

  @doc ~S"""
  If `val` is explicitly (and therefore unambiguously) false, then returns `true`.  Otherwise `false`

  Explicitly false values are case-insensitive, "f", "false", "no", "n"
  """
  def explicitly_false?(val) when is_binary(val), do: String.downcase(val) in ~w[f false no n]

  @doc ~S"""
  If `val` is explicitly true, output is true.  Otherwise false

  The effect of this is that if the string isn't explicitly true then it is
  considered false.  This is useful for example with an env var where the default
  should be `false`
  """
  def false_or_explicitly_true?(val) when is_binary(val), do: explicitly_true?(val)
  def false_or_explicitly_true?(val) when is_atom(val), do: val == true

  @doc ~S"""
  If `val` is explicitly false, output is false.  Otherwise true

  The effect of this is that if the string isn't explicitly false then it is
  considered true.  This is useful for example with an env var where the default
  should be `true`
  """
  def true_or_explicitly_false?(val) when is_binary(val), do: not explicitly_false?(val)
  def true_or_explicitly_false?(nil), do: true
  def true_or_explicitly_false?(val) when is_atom(val), do: !!val
end

defmodule DomainNameOperator.Utils.Enum do
  @doc """
  will return true if all invocations of the function return false.  If one callback returns `true`, the end result will be `false`

  `Enum.all?` will return true if all invocations of the function return
  true. `DomainNameOperator.Utils.Enum.none?` is the opposite.
  """
  def none?(enum, func) do
    Enum.all?(enum, fn i -> !func.(i) end)
  end
end

defmodule DomainNameOperator.Utils.Crypto do
  def strong_random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64(padding: false)
    |> String.replace(~r{\+}, "C")
    |> String.replace(~r{/}, "z")
    |> binary_part(0, length)
  end

  def hash_token(api_token) do
    :crypto.hash(:sha256, api_token)
    |> Base.encode64()
  end
end

defmodule DomainNameOperator.Utils.DateTime do
  def utc_now_trunc(),
    do: DateTime.truncate(DateTime.utc_now(), :second)

  @doc "Return a DateTime about 200 years into the future"
  def distant_future() do
    round(52.5 * 200 * 7 * 24 * 60 * 60)
    |> adjust_cur_time_trunc(:seconds)
  end

  # New implementation, needs testing
  # def distant_future(),
  #   do: adjust_cur_time(200, :years)

  @doc """
  Add the specified number of units to the current time.

  Supplying a negative number will adjust the time backwards by the
  specified units, while supplying a positive will adjust the time
  forwards by the specified units.
  """
  def adjust_cur_time(num_years, :years),
    do: adjust_cur_time(round(num_years * 52.5), :weeks)

  def adjust_cur_time(num_weeks, :weeks),
    do: adjust_cur_time(num_weeks * 7, :days)

  def adjust_cur_time(num_days, :days),
    do: adjust_cur_time(num_days * 24, :hours)

  def adjust_cur_time(num_hours, :hours),
    do: adjust_cur_time(num_hours * 60, :minutes)

  def adjust_cur_time(num_minutes, :minutes),
    do: adjust_cur_time(num_minutes * 60, :seconds)

  def adjust_cur_time(num_seconds, :seconds),
    do: adjust_time(DateTime.utc_now(), num_seconds, :seconds)

  def adjust_cur_time_trunc(num_weeks, :weeks),
    do: adjust_cur_time_trunc(num_weeks * 7, :days)

  def adjust_cur_time_trunc(num_days, :days),
    do: adjust_cur_time_trunc(num_days * 24, :hours)

  def adjust_cur_time_trunc(num_hours, :hours),
    do: adjust_cur_time_trunc(num_hours * 60, :minutes)

  def adjust_cur_time_trunc(num_minutes, :minutes),
    do: adjust_cur_time_trunc(num_minutes * 60, :seconds)

  def adjust_cur_time_trunc(num_seconds, :seconds),
    do: adjust_time(utc_now_trunc(), num_seconds, :seconds)

  def adjust_time(time, num_weeks, :weeks),
    do: adjust_time(time, num_weeks * 7, :days)

  def adjust_time(time, num_days, :days),
    do: adjust_time(time, num_days * 24, :hours)

  def adjust_time(time, num_hours, :hours),
    do: adjust_time(time, num_hours * 60, :minutes)

  def adjust_time(time, num_minutes, :minutes),
    do: adjust_time(time, num_minutes * 60, :seconds)

  def adjust_time(time, num_seconds, :seconds),
    do: DateTime.add(time, num_seconds, :second)

  @doc "Check if `past_time` occurs before `current_time`.  Equal date returns true"
  @spec in_the_past?(DateTime.t(), DateTime.t()) :: boolean()

  def in_the_past?(past_time, current_time),
    do: DateTime.compare(past_time, current_time) != :gt

  @doc "Check if `past_time` occurs before the current time"
  @spec in_the_past?(DateTime.t()) :: boolean()

  def in_the_past?(nil),
    do: raise(ArgumentError, message: "past_time time must not be nil!")

  def in_the_past?(past_time),
    do: in_the_past?(past_time, DateTime.utc_now())

  def expired?(expires_at, current_time),
    do: in_the_past?(expires_at, current_time)

  def expired?(nil),
    do: raise(ArgumentError, message: "expires_at time must not be nil!")

  def expired?(expires_at),
    do: in_the_past?(expires_at, DateTime.utc_now())
end

defmodule DomainNameOperator.Utils.IPv4 do
  def to_s(ip_tuple) do
    ip_tuple
    |> :inet_parse.ntoa()
    |> Kernel.to_string()
  end
end

defmodule DomainNameOperator.Utils.FromEnv do
  @spec log_str(env :: Macro.Env.t(), :mfa | :func_only) :: String.t()
  def log_str(%Macro.Env{} = env, :mfa), do: "[#{mfa_str(env)}]"
  def log_str(%Macro.Env{} = env, :func_only), do: "[#{func_str(env)}]"

  @spec log_str(env :: Macro.Env.t()) :: String.t()
  def log_str(%Macro.Env{} = env), do: log_str(env, :mfa)

  @spec mfa_str(env :: Macro.Env.t()) :: String.t()
  def mfa_str(%Macro.Env{} = env), do: mod_str(env) <> "." <> func_str(env)

  @spec func_str(env :: Macro.Env.t() | {atom(), integer()}) :: String.t()
  def func_str({func, arity}), do: "##{func}/#{arity}"
  def func_str(%Macro.Env{} = env), do: func_str(env.function)

  @spec mod_str(env :: Macro.Env.t()) :: String.t()
  def mod_str(%Macro.Env{} = env), do: Kernel.to_string(env.module)
end

defmodule DomainNameOperator.Utils.Logger do
  alias DomainNameOperator.Utils.LoggerColor

  import DomainNameOperator.Utils.FromEnv

  require Logger

  def emergency(msg), do: Logger.emergency(msg, ansi_color: LoggerColor.emergency())
  def alert(msg), do: Logger.alert(msg, ansi_color: LoggerColor.alert())
  def critical(msg), do: Logger.critical(msg, ansi_color: LoggerColor.critical())
  def error(msg), do: Logger.error(msg, ansi_color: LoggerColor.error())
  def warning(msg), do: Logger.warning(msg, ansi_color: LoggerColor.warning())
  def notice(msg), do: Logger.notice(msg, ansi_color: LoggerColor.notice())
  def info(msg), do: Logger.info(msg, ansi_color: LoggerColor.info())
  def debug(msg), do: Logger.debug(msg, ansi_color: LoggerColor.debug())
  def trace(msg), do: Logger.debug("[trace]: " <> msg, ansi_color: LoggerColor.trace())

  def emergency(%Macro.Env{} = env, msg), do: emergency(log_str(env, :mfa) <> ": " <> msg)
  def alert(%Macro.Env{} = env, msg), do: alert(log_str(env, :mfa) <> ": " <> msg)
  def critical(%Macro.Env{} = env, msg), do: critical(log_str(env, :mfa) <> ": " <> msg)
  def error(%Macro.Env{} = env, msg), do: error(log_str(env, :mfa) <> ": " <> msg)
  def warning(%Macro.Env{} = env, msg), do: warning(log_str(env, :mfa) <> ": " <> msg)
  def notice(%Macro.Env{} = env, msg), do: notice(log_str(env, :mfa) <> ": " <> msg)
  def info(%Macro.Env{} = env, msg), do: info(log_str(env, :mfa) <> ": " <> msg)
  def debug(%Macro.Env{} = env, msg), do: debug(log_str(env, :mfa) <> ": " <> msg)
  def trace(%Macro.Env{} = env, msg), do: trace(log_str(env, :mfa) <> ": " <> msg)
end

defmodule DomainNameOperator.Utils.LoggerColor do
  def green, do: :green
  def black, do: :black
  def red, do: :red
  def yellow, do: :yellow
  def blue, do: :blue
  def cyan, do: :cyan
  def white, do: :white

  def emergency, do: red()
  def alert, do: red()
  def critical, do: red()
  def error, do: red()
  def warning, do: yellow()
  def notice, do: yellow()
  def info, do: green()
  def debug, do: cyan()
  def trace, do: blue()
end

defmodule DomainNameOperator.CantBeNil do
  defexception [:message]

  def exception(opts) do
    varname = Keyword.get(opts, :varname, nil)

    msg =
      case varname do
        nil -> "value was set to nil but cannot be"
        _ -> "variable '#{varname}' was nil but cannot be"
      end

    %__MODULE__{message: msg}
  end
end

defmodule DomainNameOperator.Utils.Number do
  import DomainNameOperator.Utils, only: [defp_testable: 2]
  import Number.Delimit

  def default_int_opts(), do: [precision: 0, delimit: ",", separator: "."]
  def default_float_opts(), do: [precision: 2, delimit: ",", separator: "."]
  def default_intl_int_opts(), do: [precision: 0, delimit: ".", separator: ","]
  def default_intl_float_opts(), do: [precision: 2, delimit: ".", separator: ","]

  @spec format(number :: Number.t()) :: String.t()
  def format(number, opts \\ [])
  def format(number, opts) when is_float(number), do: format_us(number, opts)
  def format(number, opts), do: format_us(number, opts)

  @spec format_us(number :: Number.t()) :: String.t()
  def format_us(number, opts \\ [])

  def format_us(number, opts) when is_float(number) do
    number_to_delimited(number, get_float_opts(opts))
  end

  def format_us(number, opts) do
    number_to_delimited(number, get_int_opts(opts))
  end

  @spec format_intl(number :: Number.t()) :: String.t()
  def format_intl(number, opts \\ [])

  def format_intl(number, opts) when is_float(number) do
    number_to_delimited(number, get_intl_float_opts(opts))
  end

  def format_intl(number, opts) do
    number_to_delimited(number, get_intl_int_opts(opts))
  end

  defp_testable get_int_opts(opts), do: Keyword.merge(default_int_opts(), opts)
  defp_testable get_float_opts(opts), do: Keyword.merge(default_float_opts(), opts)
  defp_testable get_intl_int_opts(opts), do: Keyword.merge(default_intl_int_opts(), opts)
  defp_testable get_intl_float_opts(opts), do: Keyword.merge(default_intl_float_opts(), opts)
end
