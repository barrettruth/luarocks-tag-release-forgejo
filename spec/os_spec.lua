describe('OS', function()
  ---@type ltr.OS
  local OS = require('ltr.os')

  it('quotes shell arguments', function()
    assert.same("'simple'", OS.quote_arg('simple'))
    assert.same("'two words'", OS.quote_arg('two words'))
    assert.same("'it'\\''s'", OS.quote_arg("it's"))
    assert.same("''", OS.quote_arg(''))
  end)

  it('builds commands from argv-style arguments', function()
    assert.same("'luarocks' 'install' '--tree' '/tmp/a b'", OS.command { 'luarocks', 'install', '--tree', '/tmp/a b' })
  end)
end)
