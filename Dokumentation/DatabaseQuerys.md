-- 1. Kategorien (z. B. Frühstück, Mittag, Abend, Snacks, Pizza, Salate, ...)

create table categories (

&nbsp; id          uuid primary key default uuid\_generate\_v4(),

&nbsp; name        text not null unique,          -- z. B. "Hauptgerichte", "Beilagen"

&nbsp; description text,

&nbsp; created\_at  timestamptz default now(),

&nbsp; updated\_at  timestamptz default now()

);



-- 2. Gerichte (die Basis-Gerichte, die du als Admin anlegst)

create table dishes (

&nbsp; id              uuid primary key default uuid\_generate\_v4(),

&nbsp; category\_id     uuid references categories(id) on delete set null,

&nbsp; name            text not null,                   -- z. B. "Pizza Margherita", "Hähnchen mit Brokkoli"

&nbsp; description     text,

&nbsp; prep\_time\_min   integer,                         -- Zubereitungszeit in Minuten

&nbsp; image\_url       text,                            -- wird später von Supabase Storage kommen

&nbsp; is\_available    boolean,

&nbsp; is\_template     boolean default false,           -- true = Vorlage zum Duplizieren

&nbsp; created\_by      uuid references auth.users(id),  -- wer hat es angelegt (du als Admin)

&nbsp; created\_at      timestamptz default now(),

&nbsp; updated\_at      timestamptz default now()

);



-- 3. Optionen-Gruppen (z. B. "Protein", "Gemüse", "Soße", "Toppings", "Brotart")

create table option\_groups (

&nbsp; id          uuid primary key default uuid\_generate\_v4(),

&nbsp; name        text not null,                   -- z. B. "Proteinquelle", "Beilage"

&nbsp; type        text not null                     -- 'single' (Radio), 'multi' (Checkbox), 'quantity'

&nbsp;   check (type in ('single', 'multi', 'quantity')),

&nbsp; required    boolean default false,

&nbsp; description text,

&nbsp; sort\_order  integer default 0,

&nbsp; created\_at  timestamptz default now(),

&nbsp; updated\_at  timestamptz default now()

);



-- 4. Join-Tabelle: dish\_option\_groups

create table dish\_option\_groups (

&nbsp; dish\_id         uuid references dishes(id) on delete cascade not null,

&nbsp; option\_group\_id uuid references option\_groups(id) on delete cascade not null,

&nbsp; sort\_order      integer not null default 0,   -- Reihenfolge der Gruppen PRO Gericht

&nbsp; created\_at      timestamptz default now(),



&nbsp; -- Composite Primary Key → verhindert Duplikate

&nbsp; primary key (dish\_id, option\_group\_id)

);



-- 5. Einzelne Optionen / Komponenten innerhalb einer Gruppe

create table options (

&nbsp; id              uuid primary key default uuid\_generate\_v4(),

&nbsp; group\_id        uuid references option\_groups(id) on delete cascade not null,

&nbsp; name            text not null,                   -- z. B. "Hähnchenbrust", "Brokkoli", "Tomatensoße"

&nbsp; description     text,

&nbsp; price\_adjust    numeric(10,2) default 0,         -- falls später mal relevant

&nbsp; default\_selected boolean default false,

&nbsp; sort\_order      integer default 0,

&nbsp; is\_available    boolean,



&nbsp; -- Nährwerte pro 100g oder pro Einheit (Basis für Berechnung)

&nbsp; protein\_per\_100g    numeric(10,2),

&nbsp; carbs\_per\_100g      numeric(10,2),

&nbsp; gi                  integer,                    -- Glykämischer Index

&nbsp; gl                  numeric(10,2),              -- Glykämische Last (oft GI \* KH / 100)

&nbsp; portion\_size\_g      numeric(10,2) default 100,  -- Standardmenge für die Nährwerte

&nbsp; unit                text default 'g',           -- g, Stück, EL, etc.



&nbsp; created\_at      timestamptz default now()

);



-- 6. Bestellungen (was dein Partner bestellt)

create table orders (

&nbsp; id              uuid primary key default uuid\_generate\_v4(),

&nbsp; user\_id         uuid references auth.users(id) not null,  -- der Besteller (Partner)

&nbsp; status          text default 'new'                     -- new, confirmed, done, cancelled

&nbsp;   check (status in ('new', 'confirmed', 'done', 'cancelled')),

&nbsp; created\_at      timestamptz default now(),

&nbsp; updated\_at      timestamptz default now(),

&nbsp; total\_protein   numeric(10,2),                        -- auto-berechnet

&nbsp; total\_carbs     numeric(10,2),

&nbsp; total\_gi        numeric(10,2),

&nbsp; total\_gl        numeric(10,2),

&nbsp; notes           text

);



-- 7. Bestell-Items (eine Bestellung kann mehrere Gerichte haben, aber bei dir wahrscheinlich meist eins)

create table order\_items (

&nbsp; id              uuid primary key default uuid\_generate\_v4(),

&nbsp; order\_id        uuid references orders(id) on delete cascade not null,

&nbsp; dish\_id         uuid references dishes(id) not null,

&nbsp; quantity        integer default 1,

&nbsp; calculated\_protein  numeric(10,2),

&nbsp; calculated\_carbs    numeric(10,2),

&nbsp; calculated\_gi       numeric(10,2),

&nbsp; calculated\_gl       numeric(10,2),

&nbsp; notes           text

);



-- 8. Gewählte Optionen pro Bestell-Item (die konkrete Auswahl)

create table order\_item\_options (

&nbsp; id              uuid primary key default uuid\_generate\_v4(),

&nbsp; order\_item\_id   uuid references order\_items(id) on delete cascade not null,

&nbsp; option\_id       uuid references options(id) not null,

&nbsp; quantity        numeric(10,2) default 1,     -- falls z. B. 2x Hähnchen

&nbsp; selected        boolean default true

);





***Updates:***



**Nach Namensänderung in dishes/option\_groups** 

UPDATE dish\_option\_groups

SET dish\_id = dish\_id;   -- triggert den Trigger für jede Zeile



**Hinzufügen des Namens basierend auf der Uuid**

-- 1. Spalte hinzufügen

ALTER TABLE options

ADD COLUMN group\_name text;



-- 2. Bestehende Daten einmalig befüllen

UPDATE options o

SET group\_name = og.name

FROM option\_groups og

WHERE o.group\_id = og.id;



-- 3. Trigger-Funktion

CREATE OR REPLACE FUNCTION fill\_group\_name\_in\_options()

RETURNS TRIGGER AS $$

BEGIN

&nbsp;   SELECT name

&nbsp;   INTO NEW.group\_name

&nbsp;   FROM option\_groups

&nbsp;   WHERE id = NEW.group\_id;



&nbsp;   RETURN NEW;

END;

$$ LANGUAGE plpgsql;



-- 4. Trigger erstellen

CREATE TRIGGER trg\_fill\_group\_name\_options

&nbsp;   BEFORE INSERT OR UPDATE OF group\_id

&nbsp;   ON options

&nbsp;   FOR EACH ROW

&nbsp;   EXECUTE FUNCTION fill\_group\_name\_in\_options();

