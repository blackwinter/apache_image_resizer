module Apache

  [
    :DECLINED,
    :DONE,
    :FORBIDDEN,
    :HTTP_OK,
    :NOT_FOUND,
    :OK
  ].each { |const|
    const_set(const, const) unless const_defined?(const)
  }

end
