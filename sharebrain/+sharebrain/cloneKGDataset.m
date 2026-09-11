function cloneKGDataset(cloneLocation, datasetVersionUUID, options)
%cloneKGDataset - Clone a KG dataset version locally as a virtual bucket
%   cloneKGDataset(cloneLocation,datasetVersionUUID) recreates the folder
%   and file hierarchy of the EBRAINS dataset version datasetVersionUUID
%   under cloneLocation. Every file is created empty, so the clone shows
%   how the dataset is organised without transferring any of its data.
%
%   cloneKGDataset(...,Verbose=TF) reports progress while the bucket is
%   listed and the virtual files are created.
%
%   The bucket to clone is taken from the file repository that the dataset
%   version links to in the Knowledge Graph, so a dataset version without a
%   registered repository cannot be cloned.
%
%   See also initNansenProjectFromKGDataset,
%   ebrains.bucket.createVirtualBucket, kgpull

    arguments
        cloneLocation (1,1) string
        datasetVersionUUID (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        options.Verbose (1,1) logical = false
    end

    bucketName = resolveBucketName(datasetVersionUUID);

    ebrains.bucket.createVirtualBucket(bucketName, cloneLocation, ...
        Verbose=options.Verbose)
end

function bucketName = resolveBucketName(datasetVersionUUID)
%resolveBucketName - Name of the data proxy bucket of a dataset version

    % The repository is a linked type, so one order of links is resolved in
    % order to get the file repository itself and not a reference to it.
    datasetVersion = kgpull(datasetVersionUUID, NumLinksToResolve=1);

    if isempty(datasetVersion.repository)
        error("SHAREbrain:CloneKGDataset:NoRepository", ...
            "Dataset version '%s' has no file repository registered in " + ...
            "the Knowledge Graph, so there is no bucket to clone.", ...
            datasetVersionUUID)
    end

    repositoryIRI = datasetVersion.repository.IRI;

    % A data proxy repository is addressed as <base url>/buckets/<name>.
    bucketName = regexp(repositoryIRI, "(?<=buckets/)[^/?#]+", "match", "once");

    if ismissing(bucketName)
        error("SHAREbrain:CloneKGDataset:NotABucketRepository", ...
            "The file repository of dataset version '%s' is '%s', which " + ...
            "is not an EBRAINS data proxy bucket. Only a dataset that is " + ...
            "stored in a bucket can be cloned.", ...
            datasetVersionUUID, repositoryIRI)
    end
end
