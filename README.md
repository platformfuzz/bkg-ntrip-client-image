# bkg-ntrip-client-image

![Build and Release](https://github.com/platformfuzz/bkg-ntrip-client-image/actions/workflows/build-and-release.yml/badge.svg)

Container image for the BKG NTRIP Client (BNC) built from official source. BNC is a software package for receiving, processing, and broadcasting GNSS data streams via NTRIP (Networked Transport of RTCM via Internet Protocol).

## Features

- **NTRIP Client**: Receive GNSS correction data from NTRIP casters
- **NTRIP Server**: Re-broadcast NTRIP streams to other clients
- **RINEX v3 Output**: Generate RINEX 3 observation files with configurable intervals
- **Skeleton File Support**: Use template files for proper RINEX header structure
- **Headless Operation**: Runs without GUI, suitable for containerized deployments

## Quick Start

### NTRIP Client Mode

Receive NTRIP streams and generate RINEX files:

```bash
docker run -d --rm \
  -v $(pwd)/bnc-client.conf:/srv/bnc/conf/bnc.conf \
  -v $(pwd)/rnx:/srv/bnc/rnx \
  -v $(pwd)/logs:/srv/bnc/logs \
  bnc:latest
```

### NTRIP Server Mode (Client + Server)

Receive streams from a caster and re-broadcast them:

```bash
docker run -d --rm -p 2101:2101 \
  -v $(pwd)/bnc-server.conf:/srv/bnc/conf/bnc.conf \
  -v $(pwd)/rnx:/srv/bnc/rnx \
  -v $(pwd)/logs:/srv/bnc/logs \
  bnc:latest
```

## Configuration

### Configuration Files

- **`bnc-client.conf`**: Client-only configuration (receives streams, generates RINEX)
- **`bnc-server.conf`**: Server configuration (receives and re-broadcasts streams)

### Key Configuration Options

#### NTRIP Client Settings

```ini
# Enable NTRIP client
ntripClient=1
ntripVersion=2

# NTRIP caster URL
casterUrlList=http://user:pass@caster.example.com:2101

# Mountpoints (format: //user:pass@host:port/mountpoint format country lat lon no 2)
mountPoints=//user:pass@caster.example.com:2101/MOUNTPOINT RTCM_3 NZL -41.20 174.93 no 2
```

#### NTRIP Server Settings

```ini
# Enable NTRIP server (for re-broadcasting)
ntripServer=1
ntripServerPort=2101
```

#### RINEX Output Settings

```ini
# RINEX v3 output
rnxV3=2
rnxV3filenames=2

# Output directory
rnxPath=/srv/bnc/rnx

# Interval (15 minutes)
rnxIntr=15 min

# Sampling rate (1 second)
rnxSampl=1

# Use skeleton file as template (0 = optional, 1 = required)
rnxOnlyWithSKL=0

# Skeleton file
rnxSkel=SKL
```

### Skeleton Files

Skeleton files (`.SKL`) are RINEX header templates that define the observation types and station metadata. Place skeleton files directly in the RINEX output directory.

Example: For mountpoint `AVLN00NZL0`, create `rnx/AVLN00NZL.SKL` (or `/srv/bnc/rnx/AVLN00NZL.SKL` inside the container)

The skeleton file should contain a valid RINEX 3 header with:

- Marker name
- Receiver and antenna information
- Observation types for each GNSS system (GPS, GLONASS, Galileo, BeiDou, etc.)
- Approximate position

## Volume Mounts

| Volume           | Description                                    | Required   |
| ---------------- | ---------------------------------------------- | ---------- |
| `/srv/bnc/conf`  | Configuration files                            | Yes        |
| `/srv/bnc/logs`  | Log files                                      | Recommended|
| `/srv/bnc/rnx`   | RINEX output files and skeleton files (`.SKL`) | Recommended|

## Examples

### Example 1: Simple Client

```bash
# Create directories (skeleton files go directly in rnx/)
mkdir -p logs rnx

# Run container
docker run -d --rm \
  --name bnc-client \
  -v $(pwd)/bnc-client.conf:/srv/bnc/conf/bnc.conf \
  -v $(pwd)/rnx:/srv/bnc/rnx \
  -v $(pwd)/logs:/srv/bnc/logs \
  bnc:latest

# Check logs
docker logs bnc-client
cat logs/bnclog_*

# Check RINEX files (after first interval)
ls -lh rnx/
```

### Example 2: Server with Port Mapping

```bash
# Run server (exposes port 2101)
docker run -d --rm \
  --name bnc-server \
  -p 2101:2101 \
  -v $(pwd)/bnc-server.conf:/srv/bnc/conf/bnc.conf \
  -v $(pwd)/rnx:/srv/bnc/rnx \
  -v $(pwd)/logs:/srv/bnc/logs \
  bnc:latest

# Connect to server from another client
# Use: your-host:2101 as the caster URL
```

## Troubleshooting

### No RINEX Files Generated

1. **Check logs**: `docker logs <container-name>` or `cat logs/bnclog_*`
2. **Verify stream connection**: Look for "1 stream(s)" in logs
3. **Check permissions**: Ensure `rnx` directory is writable
4. **Wait for interval**: RINEX files are created at the configured interval (default: 15 minutes)

### Permission Errors

The container automatically fixes permissions for mounted volumes. If you see permission errors:

```bash
# Fix permissions on host (if needed)
sudo chown -R 1000:1000 logs rnx
```

### Skeleton File Not Found

- Ensure skeleton file name matches mountpoint name
- Check skeleton file is in the `rnx/` directory (or `/srv/bnc/rnx/` inside container)
- Verify `rnxSkel` path in configuration (use `.` for same directory as RINEX files, or absolute path like `/srv/bnc/rnx`)

### No Streams Configured

Check your `mountPoints` configuration format:

```text
mountPoints=//user:pass@host:port/MOUNTPOINT format country lat lon no 2
```

All fields are required. Example:

```text
mountPoints=//user:pass@caster.com:2101/STATION RTCM_3 NZL -41.20 174.93 no 2
```

## Building

```bash
docker build -t bnc:latest .
```

## References

- [BKG NTRIP Client Documentation](https://igs.bkg.bund.de/ntrip/download)
- [RINEX Format Specification](https://www.igs.org/rnx/)
- [NTRIP Protocol](https://igs.bkg.bund.de/ntrip/ntripdoc)
