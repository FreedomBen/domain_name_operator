defmodule DomainNameOperator.ProcessRecordException do
  defexception [:message]

  def exception(opts) do
    msg = Keyword.get(opts, :msg, nil)

    %__MODULE__{message: msg}
  end
end
