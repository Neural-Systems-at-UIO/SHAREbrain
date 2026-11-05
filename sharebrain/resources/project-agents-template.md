# Working with this NANSEN project

This folder is a NANSEN project for one EBRAINS dataset. The section "Dataset" of `README.md` names the dataset, its data variables and what loading each one returns; this file says how to work with any project made the same way.

## Where things are

- `README.md`: the dataset version, the local clone of its bucket, the session and subject tables, the data variables with their file adapters and descriptions, and MATLAB code that loads a variable.
- `docs/data-descriptor.md`: the data descriptor of the dataset, as Markdown. Read it for what was measured, how, and what the files and columns mean.
- `docs/kg-dataset-version.jsonld`: openMINDS metadata of the dataset version from the EBRAINS Knowledge Graph: subjects and their states (age, weight), techniques, protocols, contributors.
- `metadata/tables/*.csv`: copies of the session and subject tables, rewritten each time a table is saved. Use them to find sessions and subjects without MATLAB. The `.mat` files next to them are the tables NANSEN uses; do not edit them by hand.
- `configurations/datalocation_settings.json` and `configurations/filepath_settings.json`: the data locations (where the files of each session are) and the data variables (which file holds each variable, and its file adapter).

## Opening the project in MATLAB

The project needs NANSEN and the NANSEN-SHAREbrain module on the MATLAB path. Downloading files needs EBRAINS-MATLAB, NWB files need MatNWB, and the adapters NeoPickle, NeoNix and IgorPro need a Python with Neo, the one `pyenv` names. `env sharebrain` adds the MATLAB packages. Make the project current, then get session objects from it:

```matlab
nansen.ProjectManager().changeProject("<project name>")
project = nansen.getCurrentProject();
sessions = project.getSessionObjects();              % every session
session = project.getSessionObjects("<session id>"); % one session
```

A session object from `project.getSessionObjects` has the data location and variable models it needs to load and save data. One made in another way may not.

## Loading data

```matlab
data = session.loadData("<variable name>");
item = project.VariableModel.getItem("<variable name>");  % item.Description says what the file holds
```

The files of the dataset are empty placeholders until they are downloaded. Loading a placeholder stops with the error `NANSEN:Session:FileIsOnlineOnly`. Download the file of one variable with `session.downloadDataFile("<variable name>")`, or let loading download files with `project.setAutoDownloadRemoteFiles(true)`. Downloading needs an EBRAINS login (`ebrains.authenticate`); files can be large, so download only the sessions you need.

What `loadData` returns depends on the file adapter of the variable; run `help` on the adapter named in `README.md` to see its fields. A variable with the adapter `Default` is read with MATLAB `load`, which reads only `.mat` files.

## Saving results

Save a result of a session with `session.saveData`:

```matlab
result = struct( ...
    "Data", spikeCounts, ...
    "Description", "Number of spikes per sweep in the 500 ms step", ...
    "Inputs", "abf", ...
    "Code", "countSpikes.m, commit 1a2b3c4", ...
    "Created", datetime("now"));
session.saveData("SpikeCounts", result)
```

- `saveData` writes a `.mat` file into the session's folder in the data location `Processed`, for example `<processed root>/subject-170518/session-170518_1a/170518_1a_spike_counts.mat`, and adds the variable to the project's variable model, so `loadData` and every other session can find it.
- Save a struct with the fields above, so that the result says what it is and how it was made: `Data` (the result), `Description` (what it is, with units), `Inputs` (the variables it was computed from), `Code` (the function and version that computed it) and `Created`.
- Name result variables in UpperCamelCase, and do not reuse the name of a data variable of the dataset.
- Never write into the clone of the dataset: its files stand for the published dataset.
