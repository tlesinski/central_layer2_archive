# Central Layer 2 Archive Architecture

## Cel

Docelowy model archiwizacji powinien traktowac layer 2 jako centralny hub archiwum dla wielu layer 1.

Obecny sprawdzony flow `TWP -> TWARP` dziala end-to-end, ale jest zasadniczo single-source. Nowy projekt powinien zachowac dobre elementy techniczne z obecnego kodu, ale przeniesc konfiguracje, orkiestracje i statusy na layer 2.

Docelowy podzial:

```text
Layer 2 = control plane + processing engine + central metadata
Layer 1 = source data + controlled helper agent
```

Layer 2 decyduje:

```text
- jakie zrodla sa obslugiwane
- jakie tabele sa archiwizowane
- ktore partycje/subpartycje sa kandydatami
- kiedy wykonac import
- czy quality check przeszedl
- czy mozna zlecic truncate na layer 1
```

Layer 1 wykonuje tylko operacje zlecone przez layer 2 i udostepnia metadane techniczne o partycjach.

## Aktualny Minimalny Model Layer 2

Najprostszy praktyczny setup to trzy tabele:

```text
TW_ARCHIVE_TABLES
TW_ARCHIVE_PARTITIONS
TW_ARCHIVE_RUNS
```

`TW_ARCHIVE_SOURCES` zostalo celowo usuniete z aktualnego modelu. DB link jest
czescia konfiguracji tabeli i klucza zrodlowego.

### TW_ARCHIVE_TABLES

Konfiguracja tego, co archiwizowac i gdzie ma trafic.

```sql
SOURCE_DB_LINK        VARCHAR2(128) NOT NULL,
SOURCE_OWNER          VARCHAR2(128) NOT NULL,
SOURCE_TABLE_NAME     VARCHAR2(128) NOT NULL,
SOURCE_AGENT_SCHEMA   VARCHAR2(128) NOT NULL,
TARGET_OWNER          VARCHAR2(128) NOT NULL,
TARGET_TABLE_NAME     VARCHAR2(128) NOT NULL,
TRUNCATE_MODE         VARCHAR2(20) DEFAULT 'TRUNCATE' NOT NULL,
RETENTION_DAYS        NUMBER,
ENABLED_FLAG          VARCHAR2(1) DEFAULT 'Y' NOT NULL,
CREATED_AT            TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
UPDATED_AT            TIMESTAMP
```

Unikalnosc:

```text
SOURCE_DB_LINK + SOURCE_OWNER + SOURCE_TABLE_NAME
TARGET_OWNER + TARGET_TABLE_NAME
```

Na tym etapie jedna fizyczna tabela target ma dokladnie jeden setup archiwizacji.

### TW_ARCHIVE_PARTITIONS

Jedna tabela dla partycji i subpartycji. To upraszcza obecny podzial na `TW_ARCHIVE_PARTITIONS` i `TW_ARCHIVE_SUBPARTITIONS`.

```sql
SOURCE_DB_LINK             VARCHAR2(128) NOT NULL,
SOURCE_OWNER               VARCHAR2(128) NOT NULL,
SOURCE_TABLE_NAME          VARCHAR2(128) NOT NULL,
TARGET_OWNER               VARCHAR2(128) NOT NULL,
TARGET_TABLE_NAME          VARCHAR2(128) NOT NULL,

ARCHIVE_UNIT_TYPE          VARCHAR2(20) NOT NULL, -- PARTITION / SUBPARTITION
PARTITION_NAME             VARCHAR2(128) NOT NULL,
SUBPARTITION_NAME          VARCHAR2(128) DEFAULT '#' NOT NULL,

PARTITION_HIGH_VALUE       VARCHAR2(4000) NOT NULL,
SUBPARTITION_HIGH_VALUE    VARCHAR2(4000) DEFAULT '#' NOT NULL,
PARTITION_POSITION         NUMBER,
SUBPARTITION_POSITION      NUMBER,

ARCHIVE_STATUS             VARCHAR2(1) DEFAULT 'N' NOT NULL,
QUALITY_STATUS             VARCHAR2(1) DEFAULT 'N' NOT NULL,
TRUNCATE_STATUS            VARCHAR2(1) DEFAULT 'N' NOT NULL,

SOURCE_ROW_COUNT           NUMBER,
TARGET_ROW_COUNT           NUMBER,

LAST_RUN_ID                NUMBER,
ERROR_MESSAGE              VARCHAR2(4000),
CREATED_AT                 TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
UPDATED_AT                 TIMESTAMP
```

Unikalnosc logiczna:

```text
SOURCE_DB_LINK
SOURCE_OWNER
SOURCE_TABLE_NAME
PARTITION_HIGH_VALUE
SUBPARTITION_HIGH_VALUE
```

Reguly:

```text
ARCHIVE_UNIT_TYPE = 'PARTITION'    => SUBPARTITION_NAME = '#', SUBPARTITION_HIGH_VALUE = '#'
ARCHIVE_UNIT_TYPE = 'SUBPARTITION' => SUBPARTITION_NAME <> '#', SUBPARTITION_HIGH_VALUE <> '#'
```

Dla tabel subpartycjonowanych status parent partycji powinien byc wyliczany z dzieci, a nie utrzymywany jako osobna prawda operacyjna.

## Minimalny Agent Layer 1

Na layer 1 instalowalbym tylko cienki agent. Bez centralnej konfiguracji archiwizacji.

Zakres:

```text
- odczyt dictionary/partition info
- row count dla konkretnej partycji/subpartycji
- kontrolowany truncate konkretnej partycji/subpartycji
- opcjonalny helper do utworzenia/zrzucenia zdalnego widoku dla importu
- lokalny log bezpieczenstwa
```

Przykladowy kontrakt:

```sql
PKG_ARCHIVE_AGENT.get_partition_info(
  p_owner      IN VARCHAR2,
  p_table_name IN VARCHAR2
) RETURN archive_partition_tab PIPELINED;

PKG_ARCHIVE_AGENT.get_row_count(
  p_owner             IN VARCHAR2,
  p_table_name        IN VARCHAR2,
  p_partition_name    IN VARCHAR2,
  p_subpartition_name IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER;

PKG_ARCHIVE_AGENT.cleanup_unit(
  p_owner             IN VARCHAR2,
  p_table_name        IN VARCHAR2,
  p_partition_name    IN VARCHAR2,
  p_subpartition_name IN VARCHAR2 DEFAULT NULL,
  p_mode              IN VARCHAR2 DEFAULT 'TRUNCATE'
);

PKG_ARCHIVE_AGENT.health_check RETURN VARCHAR2;
```

Layer 1 nie powinien decydowac:

```text
- ktore tabele sa w scope
- ktore partycje sa eligible
- czy retention minal
- czy archiwizacja jest kompletna
- czy mozna purge'owac
```

To wszystko powinno zostac w layer 2.

## Processing Flow

Minimalny flow:

```text
1. DISCOVER
   Layer 2 iteruje po TW_ARCHIVE_TABLES.
   Czyta ARCHIVE_PARTITION_INFO_VW z layer 1 przez SOURCE_DB_LINK.
   Fizycznie dodaje brakujace target partycje przez ALTER TABLE ADD PARTITION.
   Ignoruje source MAXVALUE.
   Upsertuje rekordy do TW_ARCHIVE_PARTITIONS po high-value.

2. ARCHIVE
   Layer 2 laduje dane do staging i wykonuje EXCHANGE PARTITION albo
   EXCHANGE SUBPARTITION.
   INSERT jako metoda archiwizacji nie jest wspierany.

3. QUALITY
   Layer 2 liczy source rows przez agenta.
   Layer 2 liczy source i target rows.
   Ustawia QUALITY_STATUS = Y albo N.

4. TRUNCATE
   Layer 2 zleca layer 1 agentowi truncate tylko dla QUALITY_STATUS = Y.
   Retencja jest sprawdzana tutaj przez RETENTION_DAYS.
   Ustawia TRUNCATE_STATUS = Y.
```

Kazdy etap powinien miec tryb preview:

```sql
p_execute => 'N'
```

oraz tryb execute:

```sql
p_execute => 'Y'
```

## Co Przeniesc Z Obecnego Projektu

### Przeniesc prawie wprost

#### `PKG_SQL.fn_get_partition_info`

Pliki:

```text
exports/TWP/PARTMGR/packages/spec/PKG_SQL.sql
exports/TWP/PARTMGR/packages/body/PKG_SQL.sql
```

To jest dobry kandydat na czesc layer 1 agenta. Funkcja juz rozwiazuje wazny problem: czytanie `HIGH_VALUE` z dictionary i zwracanie go jako `VARCHAR2(4000)`.

Do poprawienia przed przeniesieniem:

```text
- ograniczyc lub zwalidowac p_where_clause
- rozwazyc DBMS_ASSERT dla schema/table
- najlepiej zastapic p_where_clause parametrami typowanymi
- przejsc z DBA_* na ALL_* tam, gdzie to mozliwe
```

#### `PKG_TL_LOGGING` + `MD_PROCESS_LOG`

Pliki:

```text
exports/TWARP/PARTMGR/packages/spec/PKG_TL_LOGGING.sql
exports/TWARP/PARTMGR/packages/body/PKG_TL_LOGGING.sql
exports/TWARP/PARTMGR/tables/MD_PROCESS_LOG.sql
exports/TWARP/PARTMGR/sequences/MD_PROCESS_LOG_SEQ.sql
```

To jest lepsza baza dla nowego projektu niz starszy duet `LOGGER/JOBLOGGER`, bo ma:

```text
- status procesu
- start/end date
- CLOB log message
- JSON log
- master log id
- error stack helper
```

Do poprawienia:

```text
- uproscic API pod nowy projekt
- dodac RUN_ID/JOB_STEP model
- unikac auto-tworzenia tabel w package body, jesli deploy ma byc kontrolowany
- jawnie rozroznic log centralny layer 2 i lekki log layer 1
```

### Przeniesc jako wzorzec, nie kopiowac 1:1

#### Fragmenty `TW_ARCHIVER`

Pliki:

```text
exports/TWARP/PARTMGR/packages/spec/TW_ARCHIVER.sql
exports/TWARP/PARTMGR/packages/body/TW_ARCHIVER.sql
```

Warto wykorzystac logike koncepcyjna:

```text
- identify/discover partitions
- create missing target partitions
- import via staging table
- exchange partition/subpartition
- rebuild local indexes
- quality check source vs archive counts
- reload failed partitions
```

Nie kopiowac 1:1, bo obecny kod ma ograniczenia:

```text
- stale g_tw_link = 'TWP'
- brak SOURCE_ID
- hardcoded special case TGL.GAI_BAL_TAB
- duzo dynamicznego SQL bez centralnej walidacji nazw
- fizyczne TMP_* tabele moga zostawac po bledach
- mieszanie orchestration, DDL, importu i truncate statusu w jednym pakiecie
```

Nowy pakiet layer 2 powinien raczej byc podzielony:

```text
PKG_ARCHIVE_DISCOVERY
PKG_ARCHIVE_TARGET_DDL
PKG_ARCHIVE_IMPORT
PKG_ARCHIVE_QUALITY
PKG_ARCHIVE_TRUNCATE
PKG_ARCHIVE_RUNNER
```

albo na start jeden pakiet z wyraznymi procedurami, ale bez hardcodow.

#### Fragmenty `TW_LOCAL_ARCHIVER`

Pliki:

```text
exports/TWP/PARTMGR/packages/spec/TW_LOCAL_ARCHIVER.sql
exports/TWP/PARTMGR/packages/body/TW_LOCAL_ARCHIVER.sql
```

Warto przeniesc jako inspiracje:

```text
- fn_calc_eod
- bezpieczna idea: source cleanup tylko po quality check
- truncate partition/subpartition
- drop empty partitions
```

Nie kopiowac 1:1:

```text
- layer 1 nie powinien sam wyliczac kandydatow do truncate
- usunac hardcoded TGL.GAI_BAL_TAB
- truncate powinien przyjmowac konkretne zlecenie z layer 2
- EOD policy powinna byc w layer 2, nie w layer 1
```

### Raczej nie przenosic do nowego projektu

#### `LOGGER` / `JOBLOGGER`

Pliki:

```text
exports/TWP/PARTMGR/packages/spec/LOGGER.sql
exports/TWP/PARTMGR/packages/body/LOGGER.sql
exports/TWP/PARTMGR/packages/spec/JOBLOGGER.sql
exports/TWP/PARTMGR/packages/body/JOBLOGGER.sql
```

Sa proste i dzialaja, ale dla nowej architektury centralnej lepiej oprzec sie na jednym run/process logu. `JOBLOGGER` mozna potraktowac jako pomysl na prosty job lifecycle, ale nie jako glowny mechanizm.

#### Obecne snapshot MViews `SNAP_TW_ARCHIVE_*`

Pliki:

```text
exports/TWARP/PARTMGR/materialized_views/SNAP_TW_ARCHIVE_TABLES.sql
exports/TWARP/PARTMGR/materialized_views/SNAP_TW_ARCHIVE_PARTITIONS.sql
exports/TWARP/PARTMGR/materialized_views/SNAP_TW_ARCHIVE_SUBPARTITIONS.sql
```

W nowym modelu layer 2 powinien byc wlascicielem centralnych metadanych, a nie snapshotem jednego layer 1. MViews moga byc uzyte technicznie dla cache dictionary per source, ale nie jako glowny model statusu.

## Kluczowe Decyzje Projektowe

### 1. Separacja danych w target archive

Trzeba wybrac jeden z dwoch modeli:

```text
A. Wspolne target tables dla wielu zrodel
   Wymaga SOURCE_ID w danych albo osobnego mechanizmu izolacji.

B. Oddzielne target tables/schemas per source
   Prostsze bezpieczenstwo i mniej kolizji, ale wiecej obiektow.
```

Najprostszy start: oddzielny target schema albo target table per source. Wspolne tabele sa lepsze analitycznie, ale wymagaja zmian w strukturze danych biznesowych albo wrapperow.

### 2. Partycja vs subpartycja

Jedna tabela `TW_ARCHIVE_PARTITIONS` wystarczy, jesli `ARCHIVE_UNIT_TYPE` jest jawny.

Parent status dla tabel subpartycjonowanych powinien byc widokiem/agregatem:

```text
all child units archived => parent archived
all child units quality OK => parent quality OK
```

### 3. DB link jako czesc konfiguracji tabeli

Aktualny uproszczony model nie ma osobnej tabeli zrodel. Nie robic osobnego
`SOURCE_CODE` ani `SOURCE_ID` bez swiadomego powrotu do wiekszego modelu.

```text
SOURCE_DB_LINK + SOURCE_OWNER + SOURCE_TABLE_NAME = source table setup key
```

DB link jest technicznym wskazaniem agenta layer 1 i jednoczesnie czescia
naturalnego klucza konfiguracji.

### 4. Dynamic SQL

Dynamiczny SQL bedzie potrzebny, ale powinien przechodzic przez jedna warstwe helperow:

```text
- walidacja owner/table/partition przez DBMS_ASSERT
- logowanie pelnego SQL
- preview mode
- execute mode
- kontrolowane bledy
```

### 5. TMP/staging tables

Nie powtarzac obecnego problemu z tysiacami `TMP_*`.

Rekomendacja:

```text
- staging table name zawiera RUN_ID
- cleanup staging w finally/exception
- osobna tabela rejestru staging objects
- procedura cleanup_orphan_staging
```

Jesli mozliwe, rozwazyc staly staging table per target table zamiast tworzenia wielu fizycznych tabel.

## Proponowany Start Implementacji

Kolejnosc prac dla nowego projektu:

```text
1. Utworzyc model layer 2:
   TW_ARCHIVE_TABLES
   TW_ARCHIVE_PARTITIONS
   TW_ARCHIVE_RUNS / MD_PROCESS_LOG

2. Utworzyc minimalny layer 1 agent:
   PKG_ARCHIVE_AGENT.get_partition_info
   PKG_ARCHIVE_AGENT.get_row_count
   PKG_ARCHIVE_AGENT.cleanup_unit
   PKG_ARCHIVE_AGENT.health_check

3. Zrobic discovery na layer 2:
   czyta zrodla
   pobiera partition info przez DB link
   robi merge do TW_ARCHIVE_PARTITIONS

4. Zrobic import dla jednego przypadku:
   range partition, bez subpartycji

5. Dodac subpartycje.

6. Dodac quality check.

7. Dodac controlled source truncate.
```

Pierwszy milestone powinien obslugiwac jedna tabele range-partitioned z jednego source, ale na modelu danych od razu gotowym na wiele source.

## Podsumowanie

Najwazniejsza zmiana wzgledem obecnego projektu:

```text
Layer 2 nie synchronizuje metadanych z jednego layer 1.
Layer 2 jest wlascicielem centralnego modelu archiwizacji dla wielu layer 1.
```

Kod z obecnego projektu warto potraktowac jako biblioteke sprawdzonych technik Oracle:

```text
- czytanie high_value
- dynamiczne DDL partycji
- import przez staging/exchange
- rebuild indeksow
- quality count
- procesowy logging
```

Nie warto przenosic obecnego ksztaltu architektury 1:1, bo utrwala single-source design.
