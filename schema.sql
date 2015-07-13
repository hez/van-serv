DROP TABLE remote_devices;
CREATE TABLE remote_devices (
    id INTEGER,
    type VARCHAR(128),
    name VARCHAR(128),
    read_device INTEGER,
    write_device INTEGER,
    read_address INTEGER,
    write_address INTEGER,
    value INTEGER
    );
