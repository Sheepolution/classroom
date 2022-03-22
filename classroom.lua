--
-- classroom
--
-- Copyright (c) 2021, Sheepolution
-- Modification of classic by rxi.
--
-- This module is free software; you can redistribute it and/or modify it under
-- the terms of the MIT license. See LICENSE for details.
--


local Class = {}
Class.__index = Class
Class.__paths = {}

local PATH = debug.getinfo(1, "S").short_src

local errors = {}
local paths_used = {}
local constructor_check = {}
local class_functions = {
  extend = 1,
  is = 1,
  implement = 2,
  parameters = 2,
}

local type_names = {
  ["any"] = true,
  ["nil"] = true,
  ["boolean"] = true,
  ["number"] = true,
  ["string"] = true,
  ["table"] = true,
  ["function"] = true,
  ["thread"] = true,
  ["userdata"] = true,
}


local function convert_path_to_name(path)
  while true do
    local f = path:find("/")
    if not f then
      break
    end
    path = path:sub(f + 1)
  end
  return path:sub(1, 1):upper() .. path:sub(2, path:find("%.") - 1):gsub("_(.)", path.upper)
end


local function check_access(property, meta, k, level)
  if property.am == 3 then
    local path = debug.getinfo(level, "S").short_src
    if property.pt ~= path then
      errors.property_is_private(k, property.pt, level + 1)
    end
  elseif property.am == 2 then
    local path = debug.getinfo(level, "S").short_src
    local success = false
    for _,p in ipairs(meta.__paths) do
      if p == path then
        success = true
        break
      elseif p == property.pt then
        break
      end
    end

    if not success then
      errors.property_is_protected(k, property.pt, level)
    end
  end
end


local function check_property(meta, k)
    local property = meta.__P[k]

    if not property then
        errors.property_does_not_exist(k, meta.__name, 3)
    end

    if property.st then
      errors.property_does_not_exist_static_instead(k, meta.__name, 3)
    end

    check_access(property, meta, k, 4)

    return property
end


local function get_types_string(types)
  if type(types) == "string" then
    return types
  end

  local type_string = ""
  for k,v in pairs(types) do
    if v == 1 then
      type_string = type_string .. k .. "|"
    else
      type_string = type_string .. tostring(k) .. "|"
    end
  end

  return type_string:sub(1, -2)
end


local function get_types_table(types)
  local t = {}
  types = types .. "|"
  for tp,_ in types:gmatch("(.-)(|)") do
    if tp == "?" then
      tp = "nil"
    end
    if not type_names[tp] then
      errors.unknown_type(tp, 3)
    end
    t[tp] = 1
  end
  return t
end


local function get_metatable_function(meta)
  return function ()
    local path = debug.getinfo(2, "S").short_src
    if path == PATH then
      return meta
    end
    errors.cannot_get_metatable(2)
  end
end


local function get_class(v)
  local raw = rawget(v, "__IS_CLASS")
  if raw then return v end

  local mt = getmetatable(v)
  if mt then
    mt = mt()
  end
  if mt and mt.__IS_CLASS then
      return v
    end
end


local function check_type(types, value, nillable, arg)
  if value == nil and nillable then return end
  if types.any then return end

  if not types[type(value)] and not types[value] then
    if type(value) == "table" then
      local c = get_class(value)
      if c then
        for t,kind in pairs(types) do
          if kind == 2 then
            if c:is(t) then
              return
            end
          end
        end
        if arg then
          errors.argument_not_assignable(arg, tostring(c), types, 3)
        else
          errors.type_not_assignable(tostring(c), types, 3)
        end
      end
    end
    if arg then
      errors.argument_not_assignable(arg, type(value), types, 3)
    else
      errors.type_not_assignable(type(value), types, 3)
    end
  end
end


local function simplify()
  function Class:extend()
    local cls = {}
    for k, v in pairs(self) do
      if k:find("__") == 1 then
        cls[k] = v
      end
    end

    local meta = {}
    meta.__call = Class.__call
    meta.__index = meta

    function meta.__newindex(s, k, v)
      if k:find("private_") == 1 then
        k = k:sub(9)
      elseif k:find("protected_") == 1 then
        k = k:sub(11)
      elseif k:find("public_") == 1 then
        k = k:sub(8)
      end

      if k:find("static_") == 1 then
        k = k:sub(8)
      end

      if k:find("readonly_") == 1 then
        k = k:sub(10)
      end

      while true do
        local found = false

        if k:find("class_") then
          found = true
          k = k:sub(7)
          if k:find("true_") == 1 then
            k = k:sub(6)
          elseif k:find("false_") == 1 then
            k = k:sub(7)
          end
        end

        for t,_ in pairs(type_names) do
          if k:find(t .. "_") == 1 then
            found = true
            k = k:sub(#t + 2)
          end
        end

        if not found then break end
      end

      rawset(cls, k, v)
    end

    local super_meta = {}

    function super_meta.__index(s, k)
      return self[k]
    end

    function super_meta.__call(m, s, ...)
      local name = debug.getinfo(2, "n").name
      return self[name](...)
    end

    cls.__index = cls
    cls.super = setmetatable({}, super_meta)

    setmetatable(meta, self)
    setmetatable(super_meta, self)
    setmetatable(cls, meta)
    return cls
  end


  function Class:implement(...)
    for _, cls in pairs({...}) do
      for k, v in pairs(cls) do
        if self[k] == nil then
          self[k] = v
        end
      end
    end
  end

  function Class:__tostring()
    return "Class"
  end

  function Class:__call(...)
    local obj = setmetatable({}, self)
    obj:constructor(...)
    return obj
  end

  function Class:parameters()
  end
end


function errors.property_does_not_exist(k, name, level)
  error("Property '" .. k .. "' does not exist on type '" .. name .. "'.", level + 1)
end

function errors.property_does_not_exist_static_instead(k, name, level)
  error("Property '" .. k .. "' does not exist on type '" .. name .. "'. Did you mean to access the static member '" .. name .. "." .. k .. "' instead?", level + 1)
end

function errors.property_is_private(k, path, level)
  error("Property '" .. k .. "' is private and only accessible within class '" .. convert_path_to_name(path) .. "'.", level + 1)
end

function errors.property_is_protected(k, path, level)
  error("Property '" .. k .. "' is protected and only accessible within class '" .. convert_path_to_name(path) .. "' and its subclasses.", level + 1)
end

function errors.get_types_not_assignable_message(tp, types)
  return "Type '" .. get_types_string(tp) .. "' is not assignable to type '" .. get_types_string(types) .. "'."
end

function errors.get_parameters_not_assignable_message(n, tp, types)
  return "Parameter " .. n .. " '" .. get_types_string(tp) .. "' is not assignable to parameter '" .. get_types_string(types) .. "'."
end

function errors.type_not_assignable(tp, types, level)
  error(errors.get_types_not_assignable_message(tp, types), level + 1)
end

function errors.property_not_assignable_to_base_type(k, name, baseName, tp, types, n, level)
  error("Property '" .. k .. "' in type '" .. name .. "' is not assignable to the same property in base type '" .. baseName .. "'.\n"
    .. (n and errors.get_parameters_not_assignable_message(n, tp, types) or errors.get_types_not_assignable_message(tp, types)), level + 1)
end

function errors.multiple_classes(level)
  error("Cannot define multiple classes in single file.", level + 1)
end

function errors.cannot_declare_outside_class(k, level)
  error("Cannot declare property '" .. k .. "' outside class file.", level + 1)
end

function errors.cannot_declare_inside_function(k, level)
  error("Cannot declare property '" .. k .. "' inside function.", level + 1)
end

function errors.duplicate_function_implementation(k, level)
  error("Duplicate function implementation '" .. k .. "'.", level + 1)
end

function errors.duplicate_identifier(k, level)
  error("Duplicate identifier '" .. k .. "'.", level + 1)
end

function errors.get_incorrect_extending_message(name, baseName)
  return "Class '" .. name .. "' incorrectly extends base class '" .. baseName .. "'.\n"
end

function errors.incorrect_extending_separate_declarations_private_property(name, baseName, k, level)
  error(errors.get_incorrect_extending_message(name, baseName) .. "Types have separate declarations of a private property '" .. k .. "'.", level + 1)
end

function errors.incorrect_extending_not_am_in_child(name, baseName, k, am, level)
  error(errors.get_incorrect_extending_message(name, baseName) .. "Property '" .. k .. "' is " .. am .. " in parent but not in child.", level + 1)
end

function errors.cannot_assign_to_read_only_property(k, level)
  error("Cannot assign to '" .. k .. "' because it is a read-only property", level + 1)
end

function errors.readonly_modifier_on_function(level)
  error("'readonly' modifier can only appear on a property declaration or index signature.", level + 1)
end

function errors.undefined_function_for_base_class(k, name, level)
  error("Undefined function '" .. k .."' for base class '" .. name .. "'.", level + 1)
end

function errors.constructors_must_contain_super_call(level)
  error("Constructors for derived classes must contain a 'super' call.", level + 1)
end

function errors.no_modifiers_on_constructor(level)
  error("Cannot apply data modifiers to constructor.", level + 1)
end

function errors.has_no_constructor(name, level)
  error(name .. " has no constructor.", level + 1)
end

function errors.property_not_assigned(k, level)
  error("Property '" .. k .. "' has no initializer and is not definitely assigned in the constructor.", level + 1)
end

function errors.argument_not_assignable(n, tp, types, level)
  error("Argument ".. n .. " of type '" .. tp .. "' is not assignable to parameter of type '" .. get_types_string(types) .. "'.", level + 1)
end

function errors.multiple_class_modifiers(level)
  error("Redundant multiple class modifiers.", level + 1)
end

function errors.expected_table_for_class(value, level)
  error("Expected value of type 'table' for class, but value is of type '" .. type(value) .. "'.", level + 1)
end

function errors.expected_table_values_for_class(value, level)
  error("Expected table filled with values of type 'table' for class type, but found a value of type '" .. type(value) .. "'.", level + 1)
end

function errors.expected_class_for_class(level)
  error("Expected class or instance for class type, but value is a regular table.", level + 1)
end

function errors.parameter_table_empty(level)
  error("Expected parameter definition to be of type 'string' or 'class', but parameter definition table is empty.", level + 1)
end

function errors.parameter_count_mismatch(n1, n2, k, level)
  error("Number of parameters for '" .. k .. "' overrides that of parent.\n" .. n1 .. " parameter" .. (n1 == 1 and "" or "s") .. " found in child but " .. n2 .. " parameters found in parent.",  level + 1)
end

function errors.parameter_string_class_expected(t, level)
  error("Expected parameter definition to be of type 'string' or 'class', but parameter definition is of type '" .. t .. "'.", level + 1)
end

function errors.unused_parameters(level)
  error("'parameters' is called but not applied to any function.", level + 1)
end

function errors.cannot_get_metatable(level)
  error("Cannot get metatable of class or instance.", level + 1)
end

function errors.unknown_type(tp, level)
  error("Unknown type '" .. tp .. "'.", level + 1)
end

Class.__metatable = get_metatable_function(Class)


function Class:extend()
  local cls = {}

  local meta = {}
  meta.__call = Class.__call
  meta.__tostring = Class.__tostring
  meta.__metatable = get_metatable_function(meta)

  local meta_properties = {}
  meta.__P = meta_properties

  if self.__P then
    for k,v in pairs(self.__P) do
      if not v.st then
        meta_properties[k] = v
      end
    end
  end

  local meta_path = debug.getinfo(2, "S").short_src
  meta.__path = meta_path

  if paths_used[meta_path] then
    errors.multiple_classes(2)
  end

  paths_used[meta_path] = true

  local meta_paths = {meta_path}
  meta.__paths = meta_paths
  for i,v in ipairs(self.__paths) do
    meta_paths[i + 1] = v
  end

  local meta_name = convert_path_to_name(meta_path)
  meta.__name = meta_name

  function meta.__newindex(s, k, v)
    local info = debug.getinfo(2, "nS")

    local access_modifier = 1
    local has_modifier = false

    if k:find("private_") == 1 then
      k = k:sub(9)
      access_modifier = 3
      has_modifier = true
    elseif k:find("protected_") == 1 then
      k = k:sub(11)
      access_modifier = 2
      has_modifier = true
    elseif k:find("public_") == 1 then
      k = k:sub(8)
      has_modifier = true
    end

    local static = false

    if k:find("static_") == 1 then
      k = k:sub(8)
      static = true
      has_modifier = true
    end

    local readonly = false

    if k:find("readonly_") == 1 then
      k = k:sub(10)
      readonly = true
      has_modifier = true
    end

    local types = nil
    local has_class = false
    while true do
      local found = false

      if k:find("class_") == 1 then
        local value = v
        if has_class then
          errors.multiple_class_modifiers(2)
        end

        has_class = true

        k = k:sub(7)

        local keep = false

        if k:find("true_") == 1 then
          keep = true
          k = k:sub(6)
        elseif k:find("false_") == 1 then
          k = k:sub(7)
        end

        if not keep then
          v = nil
        end

        found = true
        has_modifier = true

        if not types then
          types = {}
        end

        if type(value) ~= "table" then
          errors.expected_table_for_class(v, 2)
        end

        local c = get_class(value)
        if c then
          types[value] = 2
        else
          if #value == 0 then
            errors.expected_class_for_class(2)
          end

          for i,cl in ipairs(value) do
            if i == 1 and keep and type(cl) ~= "table" then
              v = cl
            else
              if type(cl) ~= "table" then
                errors.expected_table_values_for_class(cl, 2)
              else
                c = get_class(cl)
                if c then
                  types[c] = 2
                  if keep and i == 1 then
                    v = c
                  end
                else
                  errors.expected_class_for_class(2)
                end
              end
            end
          end
        end
      end

      for t,_ in pairs(type_names) do
        if k:find(t .. "_") == 1 then
          found = true
          has_modifier = true

          if not types then
            types = {}
          end
          types[t] = 1

          k = k:sub(#t + 2)
        end
      end

      if not found then break end
    end

    local property = meta_properties[k]

    if property then
      if not property.st then
        if info.short_src ~= meta_path then
          errors.cannot_declare_outside_class(k, 2)
        end

        if info.name then
          errors.cannot_declare_inside_function(k, 2)
        end
      else
        if info.short_src == meta_path and not info.name then
          if (type(property.v) == "function") then
            errors.duplicate_function_implementation(k, 2)
          else
            errors.duplicate_identifier(k, 2)
          end
        end
      end

      if property.pt == meta_path then
        if not property.st or has_modifier then
          if (type(property.v) == "function") then
            errors.duplicate_function_implementation(k, 2)
          else
            errors.duplicate_identifier(k, 2)
          end
        end
      end

      if not property.st or has_modifier then
        local parent_access_modifier = property.am
        if parent_access_modifier == 3 then
            if access_modifier == 3 then
              errors.incorrect_extending_separate_declarations_private_property(meta_name, self.__name, k, 2)
            else
              errors.incorrect_extending_not_am_in_child(meta_name, self.__name, k, "private", 2)
            end
        elseif parent_access_modifier == 2 then
          if access_modifier == 3 then
              errors.incorrect_extending_not_am_in_child(meta_name, self.__name, k, "protected", 2)
          end
        elseif parent_access_modifier == 1 then
          if parent_access_modifier ~= access_modifier then
              errors.incorrect_extending_not_am_in_child(meta_name, self.__name, k, "public", 2)
          end
        end

        -- In case no type was specified, use the type of the given value, unless it's nil.
        local tp = types
        if not tp then
          if v then
            local t = type(v)
            if t == "table" then
              local c = get_class(v)
              if c then
                tp = {[c] = 2}
              else
                tp = {[t] = 1}
              end
            else
              tp = {[t] = 1}
            end
          end
        end

        if property.tp and tp and (not property.tp.any and not tp.any) then
          for tn,kind in pairs(tp) do
            if kind == 1 then
              if not property.tp[tn] then
                errors.property_not_assignable_to_base_type(k, meta_name, self.__name, tp, property.tp, nil, 2)
              end
            else
              local found = false
              for ptn, pkind in pairs(property.tp) do
                if pkind == 2 then
                  if tn:is(ptn) then
                    found = true
                    break
                  end
                end
              end

              if not found then
                errors.property_not_assignable_to_base_type(k, meta_name, self.__name, tp, property.tp, nil, 2)
              end
            end
          end
        end

        if tp["function"] then
          if s.__parameters then
            if #s.__parameters > (property.pr and #property.pr or 0) then
              errors.parameter_count_mismatch(#s.__parameters, property.pr and #property.pr or 0, k, 2)
            end
          end
          if s.__parameters and property.pr and not (k == "constructor") then
            for i,param in ipairs(s.__parameters) do
              local oparam = property.pr[i]
              if not oparam.any then
                for t,kind in pairs(param) do
                  if kind == 1 then
                    if not oparam[t] then
                      errors.property_not_assignable_to_base_type(k, meta_name, self.__name, param, oparam, nil, 2)
                    end
                  else
                    local success = false
                    for ot,okind in pairs(oparam) do
                      if okind == 2 then
                        if t:is(ot) then
                          success = true
                        end
                      end
                    end
                    if not success then
                      errors.property_not_assignable_to_base_type(k, meta_name, self.__name, tostring(t), oparam, nil, 2)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    if has_modifier and k == "constructor" then
      errors.no_modifiers_on_constructor(2)
    end


    if property and property.st and not has_modifier then

      check_access(property, meta, k, 3)

      if property.ro then
        -- The value for readonly static properties can only be set upon declaration, not in the constructor.
        errors.cannot_assign_to_read_only_property(k, 2)
      end

      if property.tp then
        check_type(property.tp, v, property.nl)
      end

      meta_properties[k].v = v
    else

      if type(v) == "function" then
        if not types then
          if readonly then
            errors.readonly_modifier_on_function(2)
          end
          readonly = true
        end
      end

      local tp
      local params
      if types then
        check_type(types, v, true)
      else
        if v ~= nil then
          tp = type(v)
          if tp == "function" then
            if s.__parameters then
             params = s.__parameters

              local f = v
              v = function (slf, ...)
                local t = {...}
                for i,param in ipairs(params) do
                    check_type(param, t[i], param["nil"] or param.default ~= nil, i)
                    if t[i] == nil and param.default then
                      t[i] = param.default
                    end
                end
                return f(slf, unpack(t, 1, select("#", ...)))
              end
              rawset(s, "__parameters", nil)
            end
          elseif tp == "table" then
            local c = get_class(v)
            if c then
              tp = c
            end
          end
        end
      end

      meta_properties[k] = {
        pt = meta_path,
        am = access_modifier,
        v = v,
        st = static,
        ro = readonly,
        tp = types or tp and {[tp] = 1},
        nl = types and types["nil"],
        pr = params
      }
    end
  end

  function meta:__index(k)
    local path = debug.getinfo(2, "S").short_src
    local cf = class_functions[k]
    if cf then
      if cf == 2 then
        if path ~= meta_path then
          errors.property_is_private(k, meta_path, 2)
        end
      end
      return Class[k]
    end

    local raw = rawget(meta, k)
    if raw then
      return raw
    end

    raw = rawget(self, k)
    if raw then
      return raw
    end

    local property = meta_properties[k]
    if not property then
      return nil
    end

    local am = property.am

    if am == 3 then
      if path ~= property.pt then
        errors.property_is_private(k, property.pt, 2)
      end
    elseif am == 2 then
      local success = false
      for i,v in ipairs(meta_paths) do
        if v == path then
          success = true
        end
      end

      if not success then
        errors.property_is_protected(k, property.pt, 2)
      end
    end

    return property.v
  end

  cls.__IS_CLASS = true

  cls.__metatable = get_metatable_function(cls)

  function cls.__tostring()
    return meta_name
  end

  function cls.__newindex(s, k, v)
    local property = check_property(meta, k)
    if property then
      if property.ro then
        if debug.getinfo(2, "n").name ~= "constructor" then
          errors.cannot_assign_to_read_only_property(k, 2)
        end
      end

      if property.tp then
        check_type(property.tp, v, true)
      end

      if property.st then
        property.v = v
      else
        s.__P[k] = v
        s.__D[k] = true
      end
    end
  end

  function cls.__index(s, k)
    if k == "is" then
      return Class.is
    end
    local property = check_property(meta, k)

    if property then
      return (s.__D[k] and not property.st) and s.__P[k] or property.v
    end
  end

  local super_meta = {}

  function super_meta.__index(s, k)
    local property = self.__P[k]
    if property then
      return property.v
    else
      errors.undefined_function_for_base_class(k, self.__name, 2)
    end
  end

  function super_meta.__call(m, s, ...)
    local name = debug.getinfo(2, "n").name

    if not constructor_check[cls] then
      if name == "constructor" then
        rawget(s, "__C")[self] = true
      end
    end

    local property = self.__P[name]

    if not property then
      errors.undefined_function_for_base_class(name, self.__name, 2)
    end

    return property.v(s, ...)
  end

  setmetatable(meta, self)
  setmetatable(super_meta, self)
  meta_properties["super"] = {
    pt = meta_path,
    st = true,
    am = 3,
    ro = true,
    v = setmetatable({}, super_meta)
  }

  for k,_ in pairs(class_functions) do
    meta_properties[k] = {
      pt = meta_path,
      st = true,
      am = 3,
      ro = true,
      v = Class[k]
    }
  end

  setmetatable(cls, meta)
  return cls
end


function Class:implement(...)
  for _, cls in pairs({...}) do
    for k,v in pairs(cls.__P) do
      if not self.__P[k] then
        self.__P[k] = {
          pt = v.pt,
          am = v.am,
          v = v.v,
          st = v.st,
          ro = v.ro,
          tp = v.tp,
          nl = v.nl,
          pr = v.pr
        }
      end
    end
  end
end


function Class:is(T)
  if self == T then
    return true
  end

  local mt = getmetatable(self)()
  while mt do
    if mt == T then
      return true
    end
    mt = getmetatable(mt)
    if mt then
      mt = mt()
    end
  end
  return false
end


function Class:parameters(...)
  if self.__parameters then
    errors.unused_parameters(2)
  end

  local parameters = {}
  for i,tp in ipairs({...}) do
    local t = type(tp)
    if t == "string" then
      if tp:find("|") then
          parameters[i] = get_types_table(tp)
      else
        if not type_names[tp] then
          parameters[i] = {[t] = 1}
          parameters[i].default = tp
        else
          parameters[i] = {[tp] = 1}
        end
      end
    elseif t == "table" then
      local c = get_class(tp)
      if c then
        parameters[i] = {[c] = 2}
      else
        local p = {}
        if tp.default then
          local dtp = type(tp.default)
          if dtp == "table" then
            local c2 = get_class(dtp)
            if c2 then
              p[c2] = 2
              p.default = tp.default
            end
          end

          if not p.default then
            p.default = tp.default
            p[type(tp.default)] = 1
          end
        end
        for j,itp in ipairs(tp) do
          t = type(itp)
          if t == "table" then
            c = get_class(itp)
            if c then
              p[c] = 2
            else
              errors.parameter_string_class_expected(t, 2)
            end
          elseif t == "string" then
              p[itp] = 1
          else
              errors.parameter_string_class_expected(t, 2)
          end
        end

        local empty = true
        for k,v in pairs(p) do
          empty = false
          break
        end
        if empty then
          errors.parameter_table_empty(2)
        end
        parameters[i] = p
      end
    else
      parameters[i] = {[t] = 1}
      parameters[i].default = tp
    end
  end
  rawset(self, "__parameters", parameters)
end


function Class:__tostring()
  return self.__name
end


function Class:__call(...)
  if not self.constructor then
    errors.has_no_constructor(tostring(self), 2)
  end

  if self.__parameters then
    errors.unused_parameters(2)
  end

  local obj = setmetatable({__P = {}, __D = {}}, self)

  local constructors
  if not constructor_check[self] then
    constructors = {}
    rawset(obj, "__C", constructors)
  end

  obj:constructor(...)

  if not constructor_check[self] then
    local count = 0
    for _,_ in pairs(constructors) do
      count = count + 1
    end

    if count < #self.__paths - 1 then
      errors.constructors_must_contain_super_call(2)
    end

    rawset(obj, "__C", nil)
    constructor_check[self] = true
  end

  for k,property in pairs(self.__P) do
    if not property.nl and property.v == nil and not obj.__D[k] then
      errors.property_not_assigned(k, 2)
    end
  end

  return obj
end


local meta = {}
meta.__index = meta
meta.__metatable = {}
function meta:simplify()
  simplify()
end

function meta:__call()
  return Class:extend()
end


return setmetatable({}, meta)