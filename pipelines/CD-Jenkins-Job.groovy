properties([
  parameters([
    string(
      name: "image",
      description: "The docker image",
      defaultValue: "boilerplate:latest",
    )
  ])
])

timestamps {
  if (params.image == "") {
    error("The image parameter needs to be defined")
  }

  stage("Deploy") {
    node() {
      def container = params.image.split(":").first()
      try {
        sh """
          docker stop $container
        """
      } catch(e) {
        println e.toString()
      }

      sh """
        docker run \
          --detach \
          --name $container \
          --publish 127.0.0.1:9080:9080 \
          --rm \
            ${params.image}
      """
    }
  }
}
