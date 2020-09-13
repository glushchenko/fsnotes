# 9. GFM Markdown

## Headers h1-h6

Shortcut: `cmd + 1-6`

## Images

![](assets/128.png)
Shortcut: `cmd + shift + i`

## Bold, Italic, Strikethrough

**Bold text**
Shortcut: `cmd + b`

_Italic text_
Shortcut: `cmd + i`

~~Strike text~~
Shortcut: `cmd + y`

## Quotes 

> You can quote
> Multiple lines

Shortcut: `cmd + shift + u`

## Code blocks

Swift example:

```swift
public static func getHighlighter() -> Highlightr? {
    if let instance = self.hl {
        return instance
    }
    
    guard let highlightr = Highlightr() else {
        return nil
    }
    
    highlightr.setTheme(to: "vs")
    self.hl = highlightr
    
    return self.hl
}
```

SQL example: 

```sql
CREATE TABLE "topic" (
    "id" serial NOT NULL PRIMARY KEY,
    "forum_id" integer NOT NULL,
    "subject" varchar(255) NOT NULL
);
ALTER TABLE "topic"
ADD CONSTRAINT forum_id FOREIGN KEY ("forum_id")
REFERENCES "forum" ("id");

-- Initials
insert into "topic" ("forum_id", "subject")
values (2, 'D''artagnian');
```

Shortcut: `cmd + control + c`

## Code span

`One line code span`

Shortcut: `cmd + shift + c`

## Lists, numbered lists and todo

- Lists item

Shortcut: `control + L`

1. First Item
2. Second Item

Shortcut: `control + shift + L`

- [x] Pay bills
- [ ] Buy water

Shortcut: `cmd + t`

## Wikilinks

And WikiLinks [[WikiLinks with emoji 😎]]

Shortcut: `cmd + 9`