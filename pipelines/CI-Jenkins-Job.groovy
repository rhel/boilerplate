properties([
  parameters([
    string(
      name: "repoURL",
      description: "The repository URL",
      defaultValue: "https://github.com/rhel/boilerplate",
    )
  ])
])

timestamps {
  if (params.repoURL == "") {
    error("The repoURL parameter needs to be defined")
  }

  stage("Build") {
    node() {
      def uri = new URI(params.repoURL)
      def repository = uri.getPath().split("/").last()
      def image = sprintf("%s:latest", repository)

      dir(repository) {
        git url: params.repoURL
        docker.build(image)
      }

      writeFile file: "artifact.txt", text: image
      archiveArtifacts artifacts: "artifact.txt"
    }
  }
}
