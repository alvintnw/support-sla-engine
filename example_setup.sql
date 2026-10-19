-- Adjust the calendar to your team (defaults: Mon-Fri 09:00-17:00, Asia/Jakarta)
-- UPDATE business_calendar SET timezone = 'America/New_York', start_minute = 480, end_minute = 1080;   -- 08:00-18:00
-- UPDATE business_calendar SET work_days = '{1,2,3,4,5,6}';                                            -- include Saturday

-- Holidays do not count as business time
-- INSERT INTO holidays (day, name) VALUES ('2026-12-25', 'Christmas Day'), ('2027-01-01', 'New Year') ON CONFLICT DO NOTHING;

-- Change a target (minutes of business time)
-- UPDATE sla_policies SET first_response_min = 30 WHERE priority = 'high';

-- Add a priority
-- INSERT INTO sla_policies (priority, first_response_min, resolution_min, calendar) VALUES ('critical', 10, 120, '24x7');
