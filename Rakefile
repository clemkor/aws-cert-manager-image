$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'yaml'

require 'rake_terraform'
require 'rake_docker'
require 'confidante'

require 's3_version_file'
require 'terraform_output'

RakeTerraform.define_installation_tasks(
    path: File.join(Dir.pwd, 'vendor', 'terraform'),
    version: '0.11.1')

configuration = Confidante.configuration
version = S3VersionFile.new(
    configuration.region,
    configuration.storage_bucket_name,
    configuration.image_version_key,
    'build/version')

task :default => [
    :'bootstrap:plan',
    :'image_repository:plan'
]

namespace :version do
  task :bump do
    version.bump(:revision)
  end
end

namespace :bootstrap do
  RakeTerraform.define_command_tasks do |t|
    t.configuration_name = 'bootstrap'
    t.source_directory = 'infra/bootstrap'
    t.work_directory = 'build'

    t.state_file = lambda do
      File.join(Dir.pwd, 'state/bootstrap-default.tfstate')
    end

    t.vars = lambda do
      configuration
          .for_overrides(deployment_identifier: 'default')
          .for_scope(
              role: 'bootstrap',
              deployment: 'default')
          .vars
    end
  end
end

namespace :image_repository do
  RakeTerraform.define_command_tasks do |t|
    t.configuration_name = 'cert manager image repository'
    t.source_directory = 'infra/image-repository'
    t.work_directory = 'build'

    t.backend_config = lambda do
      configuration
          .for_overrides(deployment_identifier: 'default')
          .for_scope(
              role: 'cert-manager-image-repository',
              deployment: 'default')
          .backend_config
    end

    t.vars = lambda do
      configuration
          .for_overrides(deployment_identifier: 'default')
          .for_scope(
              role: 'cert-manager-image-repository',
              deployment: 'default')
          .vars
    end
  end
end

namespace :image do
  RakeDocker.define_image_tasks do |t|
    t.image_name = 'aws-cert-manager'
    t.work_directory = 'build/images'

    t.copy_spec = t.copy_spec = ['src/cert-manager/.']

    t.repository_name = 'eth-quest/aws-cert-manager'
    t.repository_url = lambda do
      configuration =
          configuration
              .for_overrides(deployment_identifier: 'default')
              .for_scope(
                  role: 'cert-manager-image-repository',
                  deployment: 'default')

      backend_config = configuration.backend_config

      TerraformOutput.for(
          name: 'repository_url',
          source_directory: 'infra/image-repository',
          work_directory: 'build',
          backend_config: backend_config)
    end

    t.credentials = lambda do
      configuration =
          configuration
              .for_overrides(deployment_identifier: 'default')
              .for_scope(
                  role: 'cert-manager-image-repository',
                  deployment: 'default')

      backend_config = configuration.backend_config
      region = configuration.region

      authentication_factory = RakeDocker::Authentication::ECR.new do |c|
        c.region = region
        c.registry_id = TerraformOutput.for(
            name: 'registry_id',
            source_directory: 'infra/image-repository',
            work_directory: 'build',
            backend_config: backend_config)
      end

      authentication_factory.call
    end

    t.tags = lambda do
      [version.refresh.to_s, 'latest']
    end
  end

  task :publish => [
      'version:bump',
      'image:clean',
      'image:build',
      'image:tag',
      'image:push'
  ]
end
