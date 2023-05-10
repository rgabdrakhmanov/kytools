# README

This document describes Bash functions included in the repository. Functions are meant to automate repetitive operations in situations, when same change has to be applied to a similar resources in multiple Kubernetes clusters in the abscense of the up-to-date configuration files describing current state of this resources. Especially good for complex custom resources ~500 lines long (wink wink). Each function was made to be usable, and probably even useful, on its own.

## Dependencies

- `fzf`: a command-line fuzzy finder. See [https://github.com/junegunn/fzf](https://github.com/junegunn/fzf)
- `yq`: a command-line YAML processor. See [https://github.com/mikefarah/yq](https://github.com/mikefarah/yq)
- `yaml-diff`, `yaml-validate`, `yaml-merge`: a command-line tools from YAML Path project. See [https://github.com/wwkimball/yamlpath/wiki/Command-Line-(CLI)-Tools](https://github.com/wwkimball/yamlpath/wiki/Command-Line-(CLI)-Tools)
- `kubectl`: the Kubernetes command-line tool. It must be installed and configured with access to a Kubernetes cluster.
- `kustomize`: a command-line tool used to customize Kubernetes objects. See [https://kubectl.docs.kubernetes.io/installation/kustomize/](https://kubectl.docs.kubernetes.io/installation/kustomize/)

## Installation :D

1. Install dependancies listed above and those which are not listed, as you will probably discover, because I forgot them or you use something which is not Ubuntu 22.04
2. Clone repo, go to the dir and source the file with `source kytools.sh`

Additionally to use `kysyncmerge()`, `kymerge()`, `kyindent()` you have to:

4. Create `~/yamlpath` dir
5. In the `~/yamlpath` dir create `mergepaths.txt` with at least one line which consist of a dot `.`. This is a file with the list of YAML paths indicating where in the source file your change is to be merged, where `.` mean top of the YAML file
6. In the `~/yamlpath` dir create `yaml` file or files describing your desired changes to the Kubernetes resources

Few examples of `yamlpath` dir contents are included, so instead of creating it can be copied to `~/yamlpath`.

## Description

### kysyncmerge()

The `kysyncmerge` is a simple combination of the other functions mentioned here. It saves the interactively selected resource from the Kubernetes cluster to a local YAML file using the `kysync`, then merges the interactively selected changes using `kymerge` function. It then removes fields using the `kyclean`, and finally indents the resulting YAML file using the `kyindent`.

It provides a way to generate the modified and validated YAML file from existing Kubernetes resource with one command. Generated file is then ready to be saved to a version control system or applied back to the previously selected resource in the Kubernetes cluster with `kubectl apply -f FILEPATH`.

Usage:

```bash
kysyncmerge [--file=FILEPATH]
```

- `--file=FILEPATH` (optional): The path to save the live Kubernetes object. If not specified, `fselect()` will be used to select a file interactively. The same file path will be used for all operations.

### fselect()

`fselect()` is a Bash function that allows interactive selection of a file using fzf. It excludes hidden files/directories and displays file contents in fzf preview. If no file is selected, it returns an error message.

Usage:

```bash
fselect [path]
```

- `path` (optional): The path to search for files. If not specified, the current directory is used.

### kg()

`kg()` is a Bash function that simplifies the process of selecting and retrieving Kubernetes resources. It uses `kubectl` to retrieve a list of resource types and namespaces, and then uses `fzf` to allow interactive selection of the resource and namespace. If no resource or namespace is selected, it returns an error message.

Usage:

```bash
kg [kubectl arguments]
```

- `kubectl arguments` (optional): Any arguments, apart from resource type, name and namesapce, that would normally be passed to `kubectl get`. For example: `kg -o yaml` or `kg --show-labels` will work fine.

### kydiff()

`kydiff()` is a Bash function that compares a local YAML file to a live Kubernetes object, using `yaml-diff`. It prompts the user to select a live object from the cluster interactively using `kg()`, and a local YAML file using `fselect()`, if it was not provided as parameter. It then displays the differences between the two YAML representations, and validates the local YAML file using `yaml-validate` and `kubectl diff`.

Usage:

```bash
kydiff [--file=FILEPATH]
```

- `--file=FILEPATH` (optional): The path to the local YAML file to be compared. If not specified, `fselect()` will be used to select a file interactively.

### kysync()

The `kysync` function synchronizes a Kubernetes object from the cluster to a file. It prompts the user to select a live object from the cluster interactively using `kg()`, and a local YAML file using `fselect()`, if it was not provided as parameter. It saves the live object from the cluster to a YAML file specified as a parameter or interactively selected.

Usage:

```bash
kysync [--file=FILEPATH]
```

- `--file=FILEPATH` (optional): The path to save the live Kubernetes object. If not specified, `fselect()` will be used to select a file interactively.

## kymerge()

The `kymerge()` function merges a YAML file containing changes with a source YAML file using `yaml-merge` utility. It prompts the user to provide a source file, a file containing changes, and a YAML path indicating where in the source file the change is to be merged. If any of these values are not provided as parameters, the user is prompted to select the files interactively using `fselect()`. If the `mergepath` parameter is not provided, the user is prompted to select a YAML path interactively using `fzf`.

Usage:

```bash
kymerge [--file=SOURCE_FILEPATH] [--change=CHANGE_FILEPATH] [--mergepath=YAML_PATH]
```

- `--file=SOURCE_FILEPATH` (optional): The path to the source YAML file. If not specified, `fselect()` will be used to select the file interactively.
- `--change=CHANGE_FILEPATH` (optional): The path to the YAML file containing the required changes. If not specified, `fselect()` will be used to select the file interactively.
- `--mergepath=YAML_PATH` (optional): The YAML path indicating where in the source file the change is to be merged. If not specified, `fzf` will be used to select the path interactively.

The function performs merging using `yaml-merge` and saves the resulting YAML file to the source file path provided. It then validates the resulting YAML file using `yaml-validate` and `kubectl diff`. If any of the steps fail, the function returns with exit code 1.

The `tmppath` variable is used to store the temporary path for merging and is set to `~/yamlpath` by default.

```bash
tmppath=~/yamlpath
```

### kyclean()

The `kyclean` function removes the non-essential parts of a Kubernetes object YAML file to make it suitable for editing, version control, or sharing. The removed parts include `.status`, `.metadata.uid`, `.metadata.generation`, and `.metadata.creationTimestamp`. The function prompts the user to select a YAML file interactively using `fselect()`, if it was not provided as parameter.

Usage:

```bash
kyclean [--file=FILEPATH]
```

- `--file=FILEPATH` (optional): The path to the Kubernetes object YAML file. If not specified, `fselect()` will be used to select a file interactively.

### kyindent()

!!! Required as a temporary workaround to fix indentation of resulted files

The `kyindent` function applies "Kubernetes-style" indentation to a YAML file with the help of `kubectl kustomize`. It prompts the user to select a YAML file interactively using `fselect()` if it was not provided as parameter. The indentation is performed by creating a temporary directory with a unique name to avoid overwriting existing files, creating a temporary `kustomization.yaml` file in the temporary directory, and populating it with the path to the YAML file. Finally, `kubectl kustomize` is used to perform the indentation. The temporary directory and files are then removed.

Usage:

```bash
kyindent [--file=FILEPATH]
```

- `--file=FILEPATH` (optional): The path to the YAML file to be indented. If not specified, `fselect()` will be used to select a file interactively.

The `tmppath` variable is used to store the temporary files and is set to `~/yamlpath` by default.

```bash
tmppath=~/yamlpath
```
