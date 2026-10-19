-- Support SLA Engine schema (PostgreSQL 13+). Safe to run twice.

-- One business calendar for the whole team
CREATE TABLE IF NOT EXISTS business_calendar (
  singleton    BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
  timezone     TEXT NOT NULL DEFAULT 'Asia/Jakarta',            -- any IANA name, validated by the workflow
  work_days    INT[] NOT NULL DEFAULT '{1,2,3,4,5}'
               CHECK (cardinality(work_days) >= 1 AND work_days <@ ARRAY[1,2,3,4,5,6,7]),   -- 1 = Monday ... 7 = Sunday
  start_minute INT NOT NULL DEFAULT 540  CHECK (start_minute BETWEEN 0 AND 1439),           -- 09:00
  end_minute   INT NOT NULL DEFAULT 1020 CHECK (end_minute BETWEEN 1 AND 1440),             -- 17:00
  CHECK (start_minute < end_minute)
);
INSERT INTO business_calendar (singleton) VALUES (TRUE) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS holidays (
  day  DATE PRIMARY KEY,
  name TEXT
);

-- SLA targets per priority, in minutes of business time (or wall-clock time for '24x7')
CREATE TABLE IF NOT EXISTS sla_policies (
  priority           TEXT PRIMARY KEY CHECK (priority ~ '^[a-z]{3,20}$'),
  first_response_min INT  NOT NULL CHECK (first_response_min > 0),
  resolution_min     INT  NOT NULL CHECK (resolution_min > 0),
  calendar           TEXT NOT NULL DEFAULT 'business' CHECK (calendar IN ('business', '24x7')),
  CHECK (resolution_min >= first_response_min)
);
INSERT INTO sla_policies (priority, first_response_min, resolution_min, calendar) VALUES
  ('urgent',  15,  240, '24x7'),
  ('high',    60,  480, 'business'),
  ('normal', 240, 2400, 'business'),
  ('low',    480, 4800, 'business')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS tickets (
  id                     BIGSERIAL PRIMARY KEY,
  external_id            TEXT NOT NULL UNIQUE CHECK (external_id ~ '^[A-Za-z0-9_.:-]{1,100}$'),
  subject                TEXT NOT NULL CHECK (length(subject) BETWEEN 1 AND 200),
  customer               TEXT CHECK (customer IS NULL OR length(customer) <= 100),
  assignee               TEXT CHECK (assignee IS NULL OR length(assignee) <= 100),
  priority               TEXT NOT NULL REFERENCES sla_policies(priority) ON UPDATE CASCADE,
  status                 TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'pending', 'resolved')),
  version                INT  NOT NULL DEFAULT 1,                  -- optimistic locking
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  first_response_at      TIMESTAMPTZ,
  response_met           BOOLEAN,
  resolved_at            TIMESTAMPTZ,
  resolution_met         BOOLEAN,
  response_remaining_min NUMERIC,                                   -- business minutes left while paused
  resolution_remaining_min NUMERIC,
  response_due_at        TIMESTAMPTZ,
  resolution_due_at      TIMESTAMPTZ,
  response_alert_level   SMALLINT NOT NULL DEFAULT 0 CHECK (response_alert_level BETWEEN 0 AND 2),    -- 1 warning, 2 breached
  resolution_alert_level SMALLINT NOT NULL DEFAULT 0 CHECK (resolution_alert_level BETWEEN 0 AND 2),
  -- state invariants
  CHECK ((status = 'resolved') = (resolved_at IS NOT NULL)),
  CHECK (status <> 'open' OR resolution_due_at IS NOT NULL),
  CHECK (status <> 'pending' OR (resolution_due_at IS NULL AND response_due_at IS NULL))
);
CREATE INDEX IF NOT EXISTS tickets_open_idx ON tickets (status, resolution_due_at);
