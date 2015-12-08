DROP TABLE remote_devices;
CREATE TABLE remote_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    updated_at DATETIME,
    type VARCHAR(128),
    name VARCHAR(128),
    device_type INTEGER,
    device INTEGER,
    address INTEGER,
    max_value INTEGER,
    min_value INTEGER,
    value INTEGER
    );
