## Task 1  – Basic CI/CD Using GitHub Runners
### T1.1 Set up a CI workflow
To create a CI workflow using GitHub Actions, we create a YAML file `ci_cd.yml` in the `.github/workflows/` directory.
We give it a name with the `name` field.
Then to specify trigger events, we use the `on` field in which we add the desired events : `push` and `pull_request` on the `main` branch.

To define the jobs to be run, we use the `jobs` field.
In our case, we define a single job named `build-and-test` that will execute `make` and `make test`.
We specify the operating system, here an ubuntu, to be used with `runs-on`, and we use the `steps` field to define the individual steps of the job.

- The first step checks out the repository using the `actions/checkout@v4` action, which allows the workflow to access the code.
- The second step builds the project by running the `make` command.
- The third step runs the tests using the `make test` command.

If one of the steps fails, the entire job will be failed, and the entire workflow fails.

### T1.2 Separate CI from CD / T1.3 Release artifacts
Now we want to add logic for Continuous Deployment (CD). To do this, we modify the existing `ci_cd.yml` file.
Putting the CI and CD logic in the same file allows us to see the entire pipeline in one view, and ensures that the CD process only runs if the CI process is successful.

We add a new trigger event under the `on` field for `release` events, with the type `created`, which means the CD process will run only when a new release is created.

Then we add a new job named `deploy` under the `jobs` field. As with the previous job, we specify the operating system with `runs-on`.

To ensure that it runs only if the CI is successful, we use the `needs` field to specify that the `deploy` job depends on the `build-and-test` job.

We also add an `if` condition to ensure only a `release` event can trigger the deployment.

As before, we define the steps of the job under the `steps` field.

- The first step checks out the repository.
- The second step builds the binary using `make`.
- The third step uploads a release artifact using the `softprops/action-gh-release@v2` action, where we specify the files to be included in the release.

When pushing the file, the CI/CD pipeline runs, and we can see the results in the "Actions" tab of the GitHub repository.

I created a release `v0.1' to test the CD process, and this error occurred:
```
Run softprops/action-gh-release@v2
🤔 Pattern 'dummydb' does not match any files.
Found release Initial Release (with id=276062007)
⚠️ Unexpected error fetching GitHub release for tag refs/tags/v0.1: HttpError: Resource not accessible by integration - https://docs.github.com/rest/releases/releases#update-a-release
Error: Resource not accessible by integration - https://docs.github.com/rest/releases/releases#update-a-release
```

To fix this, I added a command that renames the binary to `dummydb` and changed the upload path.

This still lead to an error:
```
Found release Patch: CI/CD Pipeline Fix (with id=276067205)
⚠️ Unexpected error fetching GitHub release for tag refs/tags/v0.1.1: HttpError: Resource not accessible by integration - https://docs.github.com/rest/releases/releases#update-a-release
Error: Resource not accessible by integration - https://docs.github.com/rest/releases/releases#update-a-release
```

To fix this, I added a `permissions` field. Now everything works as expected.


## Task 2 – Reproducible Builds Using Docker
### T2.1 Create a Dockerfile
To create a Dockerfile that uses a multi-stage build, we start by defining the base image for the build stage.
We use the `debian:bookworm` image as our base, and we name this stage `builder`. Then we install the necessary build tools using `apt-get`.

We copy the entire project into the container and run `make` to build the project, followed by `make test` to run the tests.

For the runtime stage, we use the `debian:bookworm-slim` image as our base.
We copy only the compiled binary, and the license, from the build stage to the runtime stage.
We create a non-root user named `dummyuser` to run the application.
We switch to this user using the `USER` instruction.

Finally, we define the command to run the application when the container starts using the `CMD` instruction.

### T2.2 Verify build and test in Docker
To verify the build and test in Docker, we run:
```bash
docker build .
```
This command builds the Docker image using the Dockerfile in the current directory.

Everything worked as expected. But to be sure that the `make` command builds the latest version of the code,
I added a `RUN make clean` command before the `RUN make` command in the Dockerfile.

### T2.3 Integrate Docker into CI
To integrate Docker into the CI workflow, we modify the existing `ci_cd.yml` file.
We add a new job named `docker-build` under the `build-and-test` job.
As before, we define the steps of the job under the `steps` field.
- The first step checks out the repository.
- The second step builds the Docker image using the `docker build -t dummydb:test .` command.
- The third step runs the Docker container using the `docker run --rm dummydb:test` command to ensure that the application works as expected within the container.

When pushing these changes, the CI pipeline runs as expected.

### T2.4 Publish artifacts on release
To do this, we modify the existing `ci_cd.yml` file again.

First of all, we need to add the permission to write packages in the `permissions` field.

Then, we add a new step in the `deploy` job to log in to GitHub Container Registry (GHCR) using the `docker/login-action@v3` action.
We specify the registry URL, username, and password (using the `GITHUB_TOKEN` secret) to authenticate.

Next, we add another step to build, tag and push the Docker image to GHCR, using the `docker/build-push-action@v5` action.
We specify the context, tags (including the version tag based on the release tag), and set `push` to `true` to push the image to the registry.

To ensure that the Image name is valid and lowercase, we add a step that sets an environment variable `IMAGE_NAME` by converting the repository name to lowercase.


