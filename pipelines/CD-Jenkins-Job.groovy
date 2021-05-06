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

      withEnv([
        sprintf("container=%s", container),
        sprintf("image=%s", params.image),
      ]) {
        sh '''
          consulHttpAddr=$(
            docker inspect --format '{{ .NetworkSettings.IPAddress }}' consul-server
          )
          consulHttpPort=8500
          docker run \
            --detach \
            --name $container \
            --publish 8080:8080 \
            --env CONSUL_HTTP_ADDR=${consulHttpAddr}:${consulHttpPort} \
            --rm \
              $image
        '''
      }
    }
  }
}
