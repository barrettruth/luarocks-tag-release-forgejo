---@class ltr.Rockspec
---@field generate fun(package_name: string, modrev: string, specrev: string, rockspec_template: string, meta: GenerateMeta): string
local Rockspec = {}

---@param t string[]
---@return boolean
local function list_has_lua(t)
  for _, v in pairs(t) do
    if v == 'lua' or (type(v) == 'string' and string.match(v, '^lua%s+')) then
      return true
    end
  end
  return false
end

---@class (exact) GenerateMeta
---@field ref_type github_ref_type
---@field git_server_url string The github server's URL.
---@field github_repo string The github repository (owner/repo_name).
---@field license string|nil License SPDX ID (optional).
---@field git_ref string E.g. a tag or a commit sha.
---@field summary string Package summary.
---@field detailed_description_lines string[] Detailed description (list of lines).
---@field dependencies string[] List of LuaRocks package dependencies.
---@field test_dependencies string[] List of test suite dependencies.
---@field labels string[] List of labels to add to the rockspec.
---@field copy_directories string[] List of directories to add to the rockspec's copy_directories.
---@field repo_name string The repository name.
---@field github_event_tbl GithubEvent|nil GitHub event metadata, read from GITHUB_EVENT_PATH and decoded from JSON

---@class GithubEventLicense
---@field spdx_id string?

---@class GithubEventRepository
---@field license GithubEventLicense?
---@field source GithubEventRepository?
---@field description string?
---@field topics string[]?
---@field homepage string?

---@class GithubEventPullRequestHead
---@field repo GithubEventRepository?

---@class GithubEventPullRequest
---@field head GithubEventPullRequestHead?

---@class GithubEvent
---@field repository GithubEventRepository?
---@field pull_request GithubEventPullRequest?

---Generate a rockspec from a template
---@param package_name string The name of the LuaRocks package.
---@param modrev string the version of the package - in format 3.0 must follow the format '[%w.]+-[%d]+'
---@param specrev string the version of the rockspec
---@param rockspec_template string The template rockspec
---@param meta GenerateMeta
---@return string
function Rockspec.generate(package_name, modrev, specrev, rockspec_template, meta)
  local archive_dir_suffix = meta.ref_type == 'tag' and modrev or meta.git_ref

  ---@param xs string[]?
  ---@return string lua_list_string
  local function mk_lua_list_string(xs)
    if not xs or #xs == 0 then
      return '{ }'
    end
    return "{ '" .. table.concat(xs, "', '") .. "' } "
  end

  ---@param xs string[]?
  ---@return string lua_multiline_string
  local function mk_lua_multiline_str(xs)
    if not xs or #xs == 0 then
      return "''"
    end
    return '[[\n' .. table.concat(xs, '\n') .. ']]'
  end

  local repo_url = meta.git_server_url .. '/' .. meta.github_repo
  local homepage = repo_url
  local license = ''
  ---@type GithubEventRepository?
  local repo_meta = meta.github_event_tbl
    and (
      meta.github_event_tbl.pull_request
        and meta.github_event_tbl.pull_request.head
        and meta.github_event_tbl.pull_request.head.repo
      or meta.github_event_tbl.repository
    )
  local on_missing_license = [[
    Could not get the license SPDX ID from repository event metadata.
    Please add a license file your forge can recognize,
    or specify the license type as a workflow input.
    See: https://github.com/nvim-neorocks/luarocks-tag-release#license
    ]]
  if repo_meta then
    local repo_license = repo_meta.license or repo_meta.source and repo_meta.source.license
    if meta.license then
      license = "license = '" .. meta.license .. "'"
    elseif repo_license and repo_license.spdx_id ~= '' and repo_license.spdx_id ~= 'NOASSERTION' then
      license = "license = '" .. repo_license.spdx_id .. "'"
    else
      error(on_missing_license)
    end
    if not meta.summary or meta.summary == '' then
      meta.summary = repo_meta.description and repo_meta.description or ''
    end
    if #meta.labels == 0 then
      meta.labels = repo_meta.topics and repo_meta.topics or {}
    end
    local repo_homepage = repo_meta.homepage
    if repo_homepage and repo_homepage ~= '' then
      homepage = repo_homepage
    end
  elseif meta.license then
    license = 'license = "' .. meta.license .. '"'
  end

  ---@param str string
  ---@return string
  local function escape_quotes(str)
    local escaped = str:gsub("'", "\\'")
    return escaped
  end

  if not list_has_lua(meta.dependencies) then
    table.insert(meta.dependencies, 1, 'lua >= 5.1')
  end

  local rockspec = rockspec_template
    :gsub('$git_ref', meta.git_ref)
    :gsub('$modrev', modrev)
    :gsub('$specrev', specrev)
    :gsub('$repo_url', repo_url)
    :gsub('$archive_dir_suffix', archive_dir_suffix)
    :gsub('$package', package_name)
    :gsub('$summary', escape_quotes(meta.summary))
    :gsub('$detailed_description', mk_lua_multiline_str(meta.detailed_description_lines))
    :gsub('$dependencies', mk_lua_list_string(meta.dependencies))
    :gsub('$test_dependencies', mk_lua_list_string(meta.test_dependencies))
    :gsub('$labels', mk_lua_list_string(meta.labels))
    :gsub('$homepage', homepage)
    :gsub('$license', license)
    :gsub('$copy_directories', mk_lua_list_string(meta.copy_directories))
    :gsub('$repo_name', meta.repo_name)

  return rockspec
end

return Rockspec
