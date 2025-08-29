# Nais Dashboards

This repository contains Grafana dashboards for monitoring applications running on the NAIS platform.

## Dashboards

- [Ingress Logs](./src/ingress-main.libsonnet): Display logs from the ingress controller for a specific hostname.

## Development

Dashboards are defined in [Jsonnet](https://jsonnet.org/) using the [Grafonnet](https://github.com/grafana/grafonnet-lib) library.

Jsonnet is a data templating language that allows you to define complex JSON structures in a more concise and maintainable way. Grafonnet is a Jsonnet library that provides a set of functions and objects for defining Grafana dashboards.

To compile the Jsonnet files into Grafana-compatible JSON files, you can use the `jsonnet` command-line tool. The `jsonnet-bundler` (jb) tool is used to manage dependencies.

### Structure

All dashboards are defined in the `src` directory. The `src` directory contains a set of Jsonnet files that define the dashboards. A helper script `g.libsonnet` is used to import the Grafonnet library.

Most dashboards follow the following structure:

- `src/<dashboard-name>-main.libsonnet`: The main dashboard definition.
- `src/<dashboard-name>-variables.libsonnet`: The variable definitions.
- `src/<dashboard-name>-queries.libsonnet`: The query definitions.
- `src/<dashboard-name>-panels.libsonnet`: The panel definitions.

### Install Dependencies

```bash
make install
```

### Format Jsonnet Files

```bash
make fmt
```

### Compile Dashboards

```bash
make compile
```

### Deploy Dashboards

```bash
make deploy
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
