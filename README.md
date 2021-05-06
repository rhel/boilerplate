# boilerplate

## Setup

```bash
git clone https://github.com/rhel/boilerplate.git
./boilerplate/setup.sh
```

## In order to send a SET request

```bash
wget -q -O - "http://localhost:8080/set_value?timestamp=$(date +%s)"
```

## In order to send a GET request

```bash
wget -q  -O - 'http://localhost:8080/get_value?key=timestamp'
```
