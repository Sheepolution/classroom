# Classroom

Strict OOP in Lua.

**Features**
* Inheritance.
* Access modifiers: `public`, `protected` and `private`.
* Static and read-only properties.
* Strictly typed properties and parameters.
* And almost everything else you'd expect from a proper class system.

Classroom aims to work similarly to [Typescript](https://github.com/microsoft/TypeScript), but it's more strict in some places, less in others.

## Usage

The [module](classroom.lua) should be dropped into an existing project, and required by it:

```lua
Class = require "classroom"
```

The module returns an object that allows you to create classes by calling said object.


### Creating a new class
```lua
Point = Class()

function Point:constructor()

end
```

### Creating a new class instance
```lua
local point = Point()
```

### Properties

Properties must be defined outside of the constructor. If a value other than `nil` is given, then that will be its default value.

```lua
Point = Class()

Point.x = nil
Point.y = 100

function Point:constructor()
  self.x = 10
  print(self.y) -- 100
  self.z = 10 -- ERROR! Undefined property 'z'.
end
```

Defining a property without a default value, whose value is also not set in the constructor, will result in an error. See [Data modifiers](#data-modifiers) for some exceptions.

```lua
Point = Class()

Point.x = nil
Point.y = nil

function Point:constructor()
  self.x = 10
end

-- ERROR! No value assigned to 'y'.
```


#### Data modifiers

##### Access Modifiers

By default, properties are public, but they can be made protected or private instead.

* `public` - Can be used everwhere.
* `protected` - Can only be used inside its own class and the class' children. 
* `private` - Can only be used inside its own class.

You set the access modifier by prefixing the property's name with it. These properties are then accessed without the prefixes.

```lua
Point = Class()

Point.private_x = nil
Point.private_y = nil

function Point:constructor()
  self.x = 10
  self.private_y = 10 -- ERROR! Unknown property 'private_y'.
end
```
```lua
point = Point()
point.x = 20 -- ERROR! Property 'x' is private.
```

##### Static

Static properties are accessible using the class, instead of the class instance. Properties can be made static with the `static_` prefix.

```lua
Point = Class()

Point.static_x = nil
Point.static_y = nil

function Point:constructor()
  Point.x = 10
  self.y = 10 -- ERROR! Did you mean to access the static property?
end
```

##### Read-only

The value of read-only properties cannot be edited after it has been set.  Properties can be made read-only with the `readonly_` prefix.

```lua
Point = Class()

Point.readonly_x = nil
Point.readonly_y = 10

function Point:constructor()
  self.x = 20
  self.y = 20 -- ERROR! Cannot assign to read-only property.
end
```

##### Strict types

By default, properties are of the type 'any', meaning their value can be of any type; But their type can also be set. Properties can be one or multiple of the following types:

* `any`
* `boolean`
* `number`
* `string`
* `table`
* `thread`
* `userdata`
* `nil`
* `function`
* `class` *

\* This is a special type; See below for more info.

Properties that are of the type `nil` are not required to have a value set in the constructor.

These types can be set by prefixing the property with them.

```lua
NPC = Class()

NPC.string_name = nil
NPC.number_age = nil
NPC.string_table_shirtColor = "#ff0080"
NPC.string_nil_job = nil

function NPC:constructor()
  self.name = "Steve"
  self.age = "Twenty" -- ERROR! 'string' not assignable to 'number'.
  self.evil = false
  self.shirtColor = {1, 0, .5}
  -- Not required to assign a value to self.job
end
```

If no type is specified, but a default value is given, the type of that value will be used instead.

```lua
NPC = Class()

NPC.shirtColor = "#ff0080"

function NPC:constructor()
  self.shirtColor = {1, 0, .5} -- ERROR! 'table' not assignable to 'string'.
end
```

The `class` type allows you to set one or multiple classes as the type of the property. The value that has been passed will not be set as the default value of that property, unless the prefix `true_` is added after the `class_` prefix. If you want to specify for clarity that the value should not be set, the prefix `false_` can be used instead.

```lua
NPC = Class()

NPC.class_false_friend = NPC
NPC.class_true_enemy = Villain()

function NPC:constructor()
  print(self.friend) -- nil
  print(self.enemy) -- Villain

  self.friend = Player() -- ERROR! 'Player' not assignable to 'NPC'.
end
```

If you want to set multiple classes as the type, you can use a table of classes. If the prefix `true_` is used, the first value in the table will be set as the default value.

```lua
NPC = Class()

NPC.class_true_friend = {Player(), NPC}

function NPC:constructor()
  print(self.friend) -- Player
end
```

As with any type, the `class` type can be combined with other types. Again, if you want to set a default value that's different from the class, you can do so by having it be the first value in the given table.

```lua
NPC = Class()

NPC.class_true_string_friend = {"John", Player, NPC}

function NPC:constructor()
  print(self.friend) -- "John"
end
```

##### Combinations

Data modifiers can be combined, and must be done so in the following order:

1. Access modifier (`private_`, `protected_`, `public_`)
2. Static (`static_`)
3. Read-only (`readonly_`)
4. Types (`string_`, `number_`, etc.)

Upon encountering part of the name that is not one of these prefixes, Classroom will stop looking for them. This allows you to use the prefixes in the property's name.

```lua
NPC = Class()

NPC.private_name = nil -- A private property
NPC.my_private_name = nil -- A public property
NPC.public_readonly_my_static_name = nil-- public, read-only, but not static. 
```

##### Functions

Functions can also have data modifiers, except for the constructor.

Functions are read-only by default, unless their type is specified.

```lua
NPC = Class()

NPC.private_string_name = nil

-- ERROR! Constructors cannot have data modifiers.
function NPC:private_static_constructor()
  self.name = "Steve"
end

function NPC:getName()
  return self.name
end

function NPC:function_setName(name)
  self.name = name
end
```
```lua
npc = NPC()

npc.getName = function () end -- ERROR! Cannot assign to read-only property.
npc.setName = function () end -- Allowed
```

#### Parameters

Strictly-typed parameters can be set by calling the `parameters` method right before creating the method. For each parameter you pass the type as a string.

```lua
NPC = Class()

NPC.private_string_name = nil
NPC.private_number_age = nil

NPC:parameters("string", "number")
function NPC:constructor(name, age)
  self.name = name
  self.age = age
end
```
```lua
npc = NPC("Steve", "twenty") -- ERROR! 'string' is not assignable to 'number'.
```
You can set multiple types for each parameter by separating them with a `|`, or by using a table. You want to use the latter in case you want to use classes as types. For nillable types, you can either add the type `|nil` or the shorter `|?`.

```lua
NPC = Class()

NPC.private_string_name = nil
NPC.private_number_age = nil
NPC.private_number_string_shirtColor = nil
NPC.private_table_friends = nil

NPC:parameters("string", "number", "string|number|?")
function NPC:constructor(name, age, shirtColor)
  self.name = name
  self.age = age
  self.shirtColor = shirtColor
  self.friends = {}
end

NPC:parameters({NPC, Player})
function NPC:addFriend(friend)
  table.insert(self.friends, friend)
end
```
You can set a default value for each parameter. Either you pass the value and its type will be used as the type for that parameter, or you pass a table with a `default` property.

Unlike some other programming languages, the normal parameters, nillable parameters, and parameters with default values can be placed in any order you like.

```lua
NPC = Class()

NPC.private_string_name = nil
NPC.private_number_age = nil
NPC.private_number_string_shirtColor = nil
NPC.private_table_friends = nil

-- "Steve" is not a type, so it will be used as the default value for 'name'.
-- 'age' is of the type 'number|string', with 12 as the default value.
-- 'shirtColor' does not allow for nil. This order is valid.
NPC:parameters("Steve", {default=12, "string"}, "string|number")
function NPC:constructor(name, age, shirtColor)
  self.name = name
  self.age = age
  self.shirtColor = shirtColor
  self.friends = {}
end
```

### Inheritance

Classes can be extended using `extend`. Child classes are required to call `super(self)` in the constructor. By calling `super`, you call the parent's method of the function it is used in.

```lua
Rectangle = Point:extend()

Rectangle.private_width = 0
Rectangle.private_height = 0

Rectangle:parameters(0, 0, 0, 0)
function Rectangle:constructor(x, y, width, height)
  Rectangle.super(self, x, y)
  self.width = width
  self.height = height
end
```

#### Overriding

Child classes can only use the `protected` and `public` properties of their parents. Overriding is also only allowed with these properties. When doing so, the type of the child's property must match that of the parent's property. If the parent's property is `protected`, the child property can be made `public`, but not vice versa.

When overriding functions, the type of the parameters should match those of the parent's function. The only exception being the constructor.

Matching the type means that all the types of the child's property should be present in the parent's property. If the parent's property is of the type `string|number|boolean`, then it's okay for the child's property to be of the type `string|number` or `number|boolean`, but it cannot be `string|table` or `number|nil`. Similarly the child's function can have less or equal amount of parameters than its parent's function, but not more.

```lua
Point = Class()

Point.private_number_x = nil
Point.protected_number_string_y = nil

Point:parameters(0, 0)
function Point:constructor(x, y)
  self.x = x
  self.y = y
end

function Point:parameters("number|string", "number|string")
function Point:set(x, y)
  self.x = x
  self.y = y
end
```

```lua
Rectangle = Point:extend()

Rectangle.private_number_x = nil -- ERROR! Duplicate identifier 'x'.
Rectangle.protected_table_y = nil -- ERROR! 'table' not assignable to 'number|string'.
Rectangle.private_number_width = nil
Rectangle.private_number_height = nil

Rectangle:parameters(0, 0, 0, 0)
function Rectangle:constructor(x, y, width, height)
  Rectangle.super(self, x, y)
  self.width = width
  self.height = height
end

-- 'string' is present in 'number|string' and therefore is allowed.
-- ERROR! 'number|table' not assignable to 'number|string'.
-- ERROR! Number of parameters overrides that of parent.
function Rectangle:parameters("string", "number|table", "number", "number")
function Rectangle:set(x, y, width, height)
  self.x = x
  self.y = y
  self.width = width
  self.height = height
end
```

### Using mixins

You can use `implement` to implement the properties of a class into another class. Properties that share the name of properties that the other class already has are ignored.

```lua
PointPrinter = Class()

function PointPrinter:printPosition()
  print(self.x, self.y)
end
```
```lua
Point = Class()
Point:implement(PointPrinter)

Point.public_x = 0
Point.public_y = 0

function Point:constructor(x, y)
  self.x = x
  self.y = y

  -- Would not work with private properties
  self:printPosition()
end
```

### Checking an object's type
Class instances have a built-in function `is` to check if an instance is of a certain class type.
```lua
local cow = Cow(10, 20)
print(cow:is(Cow)) -- true
print(cow:is(Mammal)) -- true
print(cow:is(Fish)) -- false
print(cow:is(Bird)) -- false
print(cow:is(Animal)) -- true
```

### Simplifying

The module does a lot of checks behind the scenes to make sure everything is done in order. This heavily impacts performance. To save performance in a release build, where these checks are not needed anymore, you can call `Class.simplify()`. This will remove all the checks, without affecting the workings of your code.

```lua
Class.simplify()
```
```lua
Point = Class()
Point.private_number_x = nil
Point.private_number_y = nil

Point:parameters(0, 0)
function Point:constructor(x, y)
  self.x = x
  self.y = y
end
```
```lua
-- No errors.
point = Point("foo", {})
point.x = "bar"
point.y = function () end
```

### Limitations

To check if properties are accessed from the correct directory the module looks at the file path. Therefore the module only allows for one class for each file.

## Why?

This module was made as a challenge. Using the power of metatables, to what end can we reach the strict OOP that so many other programming languages have? This module is not recommended for serious usage. Besides performance issues, strict OOP simply does not belong in the mindset of the Lua language. That said, if someone does complain about the lack of strict OOP in Lua, this module is their answer.

## License

This module is free software; you can redistribute it and/or modify it under the terms of the MIT license. See [LICENSE](LICENSE) for details.

This module is based on [rxi](https://github.com/rxi)'s [classic](https://github.com/rxi/classic).