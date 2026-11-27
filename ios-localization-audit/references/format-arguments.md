# Format argument checks

Use this helper only for catalog keys confirmed by their call sites to be format strings. A percent sign in ordinary text does not establish a format-string contract. Select keys explicitly; the helper deliberately has no scan-every-key mode.

```sh
python3 /absolute/path/to/ios-localization-audit/scripts/check_format_arguments.py Localizable.xcstrings --key 'message.key' --locale de --locale fr
```

The source-language stringUnit takes precedence over the key; without one, the key is the source fallback. Only flat stringUnit entries are compared. Variations, substitutions, and unsupported syntax produce manual-review entries, not a successful comparison. Entries marked nontranslatable are skipped. Unknown requested keys or malformed catalog structures are input errors.

Supported syntax includes object placeholders, common signed/unsigned integer conversions and length modifiers, floating-point conversions, explicit argument positions, fixed numeric width/precision, and escaped percent signs. Dynamic width/precision, mixed positional/sequential arguments, named plural tokens, character/pointer conversions, and unrecognized tokens require manual inspection. Format tokens are bounded to 128 characters for parsing; very large or unusual formats require manual inspection.

An explicit argument position identifies the same supplied argument across translations. Reordering or repeating that position can be legitimate. Integer presentation changes such as unsigned decimal to hexadecimal preserve the declared argument type, but may still alter meaning. The q and ll length modifiers are treated as aliases. Other length/signedness changes remain visible, even when platform ABI widths happen to match.

Findings report declared format differences:

- `argument-type-change`: inspect the actual supplied argument and platform before changing the format.
- `argument-added-review` / `argument-omitted-review`: check product intent and actual arguments; an omitted interpolation is not automatically a crash.
- `missing-locale-review`: check the intended fallback policy.
- `manual-review`: comparison was not established for that entry.

Equal signatures do not prove translation meaning, presentation, or runtime correctness. This is not a format-string validator or a replacement for compilation. The tool never executes formats or writes catalogs. Exit 0 means inspection completed, including findings; exit 2 means invalid/unreadable input.

See Apple's [String Format Specifiers](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html) for the underlying Foundation format conventions. Test actual formatting on the target platform when behavior matters.
