# Central Layer 3 Replica Architecture

## Cel

Layer 3 ma byc osobna warstwa repliki danych archiwalnych z layer 2.
Nie zastepuje layer 2 i nie decyduje o archiwizacji danych zrodlowych.

Docelowy podzial:

```text
Layer 1 = dane biezace / operacyjne
Layer 2 = pelna historia i centralne archiwum prawdy
Layer 3 = odchudzona replika wycinka layer 2, np. ostatnie 365 dni
```

Layer 3:

```text
- czyta metadane i fizyczne tabele layer 2
- replikuje tylko dane z layer 2, ktore przeszly archive i quality
- trzyma target tabele 1:1 strukturalnie wzgledem layer 2
- utrzymuje wlasne statusy, runy i logi
- usuwa dane lokalnie przez PURGE, bez zadnego truncate na layer 1
```

Layer 3 nie wykonuje source cleanup na layer 1 i nie modyfikuje layer 2.

## Model Topologii

Layer 3 musi dzialac zarowno lokalnie, jak i zdalnie:

```text
L2 i L3 w tej samej bazie  => SOURCE_DB_LINK = 'LOCAL'
L2 i L3 w roznych bazach   => SOURCE_DB_LINK wskazuje DB link do layer 2
```

Control plane layer 3 dziala po stronie bazy L3. Staging i EXCHANGE sa lokalne
dla target tabel L3. Layer 2 jest zrodlem czytanym przez `SOURCE_DB_LINK`.

Na L3 moga istniec synonimy o nazwach takich jak obiekty L2, np.
`TW_ARCHIVE_TABLES` i `TW_ARCHIVE_PARTITIONS`, wskazujace lokalnie albo przez DB
link na metadane layer 2. Lokalna logika L3 powinna jednak operowac przez wlasne
widoki procesowe `TW_REPLICA_*_VW`.

## Minimalny Model Layer 3

Podstawowy model warstwy 3:

```text
TW_REPLICA_TABLES
TW_REPLICA_PARTITIONS
TW_REPLICA_RUNS
MD_PROCESS_LOG
```

`MD_PROCESS_LOG` moze byc tym samym technicznym modelem logowania co w layer 2,
ale instalowanym w schemacie L3.

### TW_REPLICA_TABLES

Konfiguracja mapowania tabel layer 2 -> layer 3.

```sql
SOURCE_DB_LINK      VARCHAR2(128) NOT NULL,
SOURCE_OWNER        VARCHAR2(128) NOT NULL,
SOURCE_TABLE_NAME   VARCHAR2(128) NOT NULL,
TARGET_OWNER        VARCHAR2(128) NOT NULL,
TARGET_TABLE_NAME   VARCHAR2(128) NOT NULL,
PARALLEL_DEGREE     NUMBER DEFAULT 4 NOT NULL,
TABLESPACE_NAME     VARCHAR2(128) DEFAULT 'USERS' NOT NULL,
DAYS_ONLINE         NUMBER DEFAULT 365 NOT NULL,
ENABLED_FLAG        VARCHAR2(1) DEFAULT 'Y' NOT NULL,
CREATED_AT          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
UPDATED_AT          TIMESTAMP
```

Unikalnosc:

```text
SOURCE_DB_LINK + SOURCE_OWNER + SOURCE_TABLE_NAME
TARGET_OWNER + TARGET_TABLE_NAME
```

Konfiguracja jest reczna. Nawet jesli tabela ma setup, `ENABLED_FLAG = 'N'`
blokuje jej przetwarzanie.

`DAYS_ONLINE` okresla okno danych trzymanych w L3. Domyslnie jest to 365 dni.
Data bazowa nie pochodzi z `SYSDATE` ani `DAT`, tylko z najnowszej poprawnej
jednostki dostepnej w layer 2:

```text
base_date = max(FN_ARCHIVE_HIGH_VALUE_DATE(PARTITION_HIGH_VALUE))
            dla L2 ARCHIVE_STATUS = Y i QUALITY_STATUS = Y

cutoff_date = base_date - DAYS_ONLINE
```

`PRESERVE_RULE` nie jest czescia v1 layer 3. Moze zostac dodany pozniej.

### TW_REPLICA_PARTITIONS

Jedna tabela dla partycji i subpartycji L3.

```sql
SOURCE_DB_LINK            VARCHAR2(128) NOT NULL,
SOURCE_OWNER              VARCHAR2(128) NOT NULL,
SOURCE_TABLE_NAME         VARCHAR2(128) NOT NULL,
TARGET_OWNER              VARCHAR2(128) NOT NULL,
TARGET_TABLE_NAME         VARCHAR2(128) NOT NULL,

ARCHIVE_UNIT_TYPE         VARCHAR2(20) NOT NULL, -- PARTITION / SUBPARTITION
SOURCE_PARTITION_NAME     VARCHAR2(128) NOT NULL,
SOURCE_SUBPARTITION_NAME  VARCHAR2(128) DEFAULT '#' NOT NULL,
PARTITION_NAME            VARCHAR2(128) NOT NULL,
SUBPARTITION_NAME         VARCHAR2(128) DEFAULT '#' NOT NULL,

PARTITION_HIGH_VALUE      VARCHAR2(4000) NOT NULL,
SUBPARTITION_HIGH_VALUE   VARCHAR2(4000) DEFAULT '#' NOT NULL,
PREV_PARTITION_HIGH_VALUE VARCHAR2(4000),

REPLICA_STATUS            VARCHAR2(1) DEFAULT 'N' NOT NULL,
QUALITY_STATUS            VARCHAR2(1) DEFAULT 'N' NOT NULL,
PURGE_STATUS              VARCHAR2(1) DEFAULT 'N' NOT NULL,

SOURCE_ROW_COUNT          NUMBER,
TARGET_ROW_COUNT          NUMBER,

LAST_RUN_ID               NUMBER,
ERROR_MESSAGE             VARCHAR2(4000),
CREATED_AT                TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
UPDATED_AT                TIMESTAMP
```

Klucz logiczny:

```text
SOURCE_DB_LINK
SOURCE_OWNER
SOURCE_TABLE_NAME
PARTITION_HIGH_VALUE
SUBPARTITION_HIGH_VALUE
```

Nowe jednostki po discovery dostaja:

```text
REPLICA_STATUS = N
QUALITY_STATUS = N
PURGE_STATUS   = N
```

Startowa partycja `P_ERROR` jest seedowana jako juz obsluzona:

```text
REPLICA_STATUS = Y
QUALITY_STATUS = Y
PURGE_STATUS   = Y
```

## Partycjonowanie I Target Tabele

Layer 3 v1 wspiera target tables:

```text
RANGE
RANGE-LIST
```

Target tabele L3 sa tworzone recznie albo seedem przed discovery. Musza istniec
z partycja startowa `P_ERROR`. Proces runtime L3 nie tworzy calej tabeli, tylko
dodaje brakujace partycje.

Zasady nazw:

```text
PARTITION_NAME    kopiowane z fizycznych nazw partycji layer 2
SUBPARTITION_NAME wynikaja z template target tabeli L3
```

Dla RANGE-LIST mapping subpartycji musi byc oparty o
`SUBPARTITION_HIGH_VALUE`, nie o fizyczna nazwe subpartycji. Template L3 musi
byc zgodny z template L2; roznica template powinna konczyc proces bledem.

`MAXVALUE` jest ignorowane i nie powinno byc replikowane do L3.

Wspierane sa tylko lokalne indeksy na target L3, takze unique local. Constraints
PK/UK nie sa przenoszone ani obslugiwane przez proces EXCHANGE.

## Widoki Procesowe

Layer 3 powinien miec wlasne widoki diagnostyczno-procesowe:

```text
TW_REPLICA_SOURCE_PARTITIONS_VW
TW_REPLICA_DISCOVERY_PARTITIONS_VW
TW_REPLICA_REPLICATE_PARTITIONS_VW
TW_REPLICA_QUALITY_PARTITIONS_VW
TW_REPLICA_PURGE_PARTITIONS_VW
```

Widoki maja pokazac przed uruchomieniem procesu, co zostanie przetworzone.
To jest ten sam wzorzec operacyjny co w layer 2.

Zrodlem dla widokow sa:

```text
- TW_REPLICA_TABLES lokalne w L3
- TW_REPLICA_PARTITIONS lokalne w L3
- metadane L2: TW_ARCHIVE_TABLES, TW_ARCHIVE_PARTITIONS
- fizyczne tabele danych L2 wskazane przez SOURCE_DB_LINK
```

Kandydatami z L2 sa tylko jednostki:

```text
ARCHIVE_STATUS = Y
QUALITY_STATUS = Y
```

`TRUNCATE_STATUS` z L2 nie jest wymagany dla L3.

## Processing Flow

### 1. DISCOVER

DISCOVER odwzorowuje strukture layer 2 do layer 3.

```text
- czyta poprawne jednostki L2 z ARCHIVE_STATUS = Y i QUALITY_STATUS = Y
- ignoruje MAXVALUE
- dodaje brakujace partycje do target tabel L3
- dla RANGE-LIST wyznacza target subpartition name z template L3 po high value
- wstawia rekordy do TW_REPLICA_PARTITIONS
- nowe rekordy dostaja N/N/N
```

DISCOVER nie ogranicza sie do `DAYS_ONLINE`. Liczba partycji L2/L3 powinna
dazyc do 1:1 strukturalnie, nawet jesli czesc danych w L3 bedzie pusta po
PURGE albo nigdy nie zostanie zaladowana.

Discovery ma dzialac fail-fast. Jesli metadane i fizyczne partycje sa w
anomalii, proces powinien zakonczyc sie bledem zamiast ukrywac problem.

### 2. REPLICATE

REPLICATE laduje dane z L2 do L3.

```text
- czyta TW_REPLICA_REPLICATE_PARTITIONS_VW
- bierze tylko jednostki w oknie DAYS_ONLINE
- nie rusza jednostek z PURGE_STATUS = Y
- tworzy lokalny staging w L3
- laduje staging z fizycznej tabeli L2 przez SOURCE_DB_LINK
- buduje lokalne indeksy staging na podstawie lokalnych indeksow target L3
- wykonuje EXCHANGE PARTITION albo EXCHANGE SUBPARTITION w L3
- ustawia REPLICA_STATUS = Y i TARGET_ROW_COUNT
```

Okno jest liczone per tabela:

```text
partition_high_value_date > cutoff_date
```

Dla RANGE-LIST okno liczy sie po `PARTITION_HIGH_VALUE`, nie po
`SUBPARTITION_HIGH_VALUE`.

Jednostki poza oknem po discovery zostaja w statusie `N/N/N`; proces REPLICATE
ich nie laduje.

### 3. QUALITY

QUALITY porownuje L2 i L3.

```text
- czyta TW_REPLICA_QUALITY_PARTITIONS_VW
- liczy source rows w fizycznej jednostce L2
- liczy target rows w fizycznej jednostce L3
- ustawia SOURCE_ROW_COUNT i TARGET_ROW_COUNT
- ustawia QUALITY_STATUS = Y albo N
```

W v1 quality to count L2 vs L3. Checksum nie jest wymagany.

Zakladamy, ze L2 jest immutable po `ARCHIVE_STATUS = Y` i `QUALITY_STATUS = Y`.
L3 nie wykrywa automatycznie reloadow tej samej jednostki w L2.

### 4. PURGE

PURGE utrzymuje lokalne okno danych w L3.

```text
- czyta TW_REPLICA_PURGE_PARTITIONS_VW
- kandydat ma REPLICA_STATUS = Y, QUALITY_STATUS = Y, PURGE_STATUS = N
- kandydat jest poza oknem DAYS_ONLINE
- wykonuje TRUNCATE PARTITION albo TRUNCATE SUBPARTITION na target L3
- ustawia PURGE_STATUS = Y
```

Dla RANGE-LIST PURGE czysci pojedyncze subpartycje.

Po `PURGE_STATUS = Y` jednostka nie jest automatycznie reimportowana. Reimport
wymaga manualnego resetu statusu.

### 5. RUNNER

Runner L3 orkiestruje:

```text
DISCOVER -> REPLICATE -> QUALITY -> PURGE
```

Kazdy proces powinien miec:

```sql
p_execute           IN VARCHAR2 DEFAULT 'N',
p_target_owner      IN VARCHAR2 DEFAULT NULL,
p_target_table_name IN VARCHAR2 DEFAULT NULL
```

Runner powinien miec `stop_after_step` i osobny execute switch dla PURGE,
analogicznie do ostroznosci zastosowanej w layer 2 dla TRUNCATE.

## Pakiety

Rekomendowane nazwy pakietow:

```text
PKG_REPLICA_DISCOVERY
PKG_REPLICA_REPLICATE
PKG_REPLICA_QUALITY
PKG_REPLICA_PURGE
PKG_REPLICA_RUNNER
```

Stan implementacji:

```text
PKG_REPLICA_DISCOVERY - zaimplementowany
PKG_REPLICA_REPLICATE - zaimplementowany
PKG_REPLICA_QUALITY   - zaimplementowany
PKG_REPLICA_PURGE     - zaimplementowany
PKG_REPLICA_RUNNER    - zaimplementowany
```

Pakiety moga reuzyc wzorce i fragmenty kodu z layer 2, ale nie powinny
parametryzowac bezposrednio `PKG_ARCHIVE_*`, zeby nie mieszac semantyki
archiwizacji L1 -> L2 z replikacja L2 -> L3.

Pomocnicze elementy z layer 2, ktore warto wykorzystac:

```text
PKG_SQL
PKG_ARCHIVE_LOG pattern
PKG_ARCHIVE_PARTITION staging/exchange ideas
FN_ARCHIVE_HIGH_VALUE_DATE
MD_PROCESS_LOG
summary formatting
```

## Logowanie I Statusy

Layer 3 loguje procesy podobnie jak layer 2:

```text
- jeden run obejmuje wiele tabel
- opcjonalny filtr target owner/table
- preview i execute mode
- summary w MD_PROCESS_LOG jako formatowana tabela
- szczegoly SQL logowane przez PKG_SQL
```

Summary powinno zawierac co najmniej:

```text
SOURCE_DB_LINK
SOURCE_OWNER
SOURCE_TABLE_NAME
TARGET_OWNER
TARGET_TABLE_NAME
SOURCE_PARTITION_NAME
SOURCE_SUBPARTITION_NAME
PARTITION_NAME
SUBPARTITION_NAME
PARTITION_HIGH_VALUE
SUBPARTITION_HIGH_VALUE
REPLICA_STATUS
QUALITY_STATUS
PURGE_STATUS
SOURCE_ROW_COUNT
TARGET_ROW_COUNT
```

## Pierwszy Milestone V1

Pierwszy milestone powinien byc lokalnym smoke w tej samej bazie:

```text
L2 schema: CARCH
L3 schema: CREPL
SOURCE_DB_LINK = LOCAL
```

Zakres smoke:

```text
- RANGE target
- RANGE-LIST target
- target tabele L3 tworzone seedem z P_ERROR
- lokalne indeksy na L3 target
- DISCOVER execute - zaimplementowany w deploy/layer3/smoke_replica_discovery.sql
- REPLICATE execute - zaimplementowany w deploy/layer3/smoke_replica_replicate.sql
- QUALITY execute - zaimplementowany w deploy/layer3/smoke_replica_quality.sql
- PURGE preview - zaimplementowany w deploy/layer3/smoke_replica_purge_preview.sql
```

Pierwszy smoke nie musi obejmowac:

```text
- zdalnej bazy L3
- PRESERVE_RULE
- checksum quality
- automatycznego tworzenia target tabel
- realnego PURGE execute
```

## Zalozenia I Decyzje Zamkniete

```text
- L3 jest osobna warstwa, nie rozszerzeniem statusow L2.
- Metadane L3 maja prefix TW_REPLICA_*.
- Pakiety L3 maja prefix PKG_REPLICA_*.
- Procesy L3: DISCOVER, REPLICATE, QUALITY, PURGE.
- Statusy jednostek L3: REPLICA_STATUS, QUALITY_STATUS, PURGE_STATUS.
- Target L3 wspiera RANGE i RANGE-LIST.
- Target L3 jest 1:1 strukturalnie wzgledem target L2.
- Discovery odwzorowuje strukture L2 1:1.
- Replicate laduje tylko okno DAYS_ONLINE.
- Purge robi TRUNCATE, nie DROP.
- Dla subpartycji purge czysci pojedyncza subpartycje.
- P_ERROR jest seedowane jako Y/Y/Y.
- L2 jest immutable po archive + quality.
- L3 nie modyfikuje L2.
- L3 nie wykonuje truncate na L1.
```
