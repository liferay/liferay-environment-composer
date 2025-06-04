package com.liferay.docker.workspace.environments

import org.gradle.api.Project
import org.gradle.api.file.ConfigurableFileTree
import org.gradle.api.file.FileTree
import org.gradle.api.GradleException


class Config {

	public Config(Project project) {
		Integer clusterNodes = project.getProperty("lr.docker.environment.cluster.nodes") as Integer

		if (clusterNodes != null) {
			this.clusterNodes = clusterNodes
		}

		this.composeFiles.add("docker-compose.yaml")

		this.composeFiles.addAll(this.toList(project.getProperty("lr.docker.environment.compose.files")))

		String clearVolumeData = project.getProperty("lr.docker.environment.clear.volume.data")

		if (clearVolumeData != null) {
			this.clearVolumeData = clearVolumeData.toBoolean()
		}

		String databaseName = project.getProperty("lr.docker.environment.database.name")

		if (databaseName != null) {
			this.databaseName = databaseName
		}

		String databasePartitioningEnabled = project.getProperty("lr.docker.environment.database.partitioning.enabled")

		if (databasePartitioningEnabled != null) {
			this.databasePartitioningEnabled = databasePartitioningEnabled.toBoolean()
		}

		String dataDirectory = project.getProperty("lr.docker.environment.data.directory")

		if (dataDirectory != null && dataDirectory.length() > 0) {
			this.dataDirectory = dataDirectory
		}

		String documentLibraryFileListOnly = project.getProperty("lr.docker.environment.liferay.document.library.file.list.only")

		if (documentLibraryFileListOnly != null) {
			this.documentLibraryFileListOnly = documentLibraryFileListOnly.toBoolean()
		}

		List hotfixURLs = this.toList(project.getProperty("lr.docker.environment.hotfix.urls"))

		if (!hotfixURLs.isEmpty()) {
			this.hotfixURLs = hotfixURLs
		}

		Integer liferayLXCEnvironmentHistoryCount = project.getProperty("lr.docker.environment.liferay-lxc.environment.history.count") as Integer

		if (liferayLXCEnvironmentHistoryCount != null) {
			this.liferayLXCEnvironmentHistoryCount = Math.max(1, liferayLXCEnvironmentHistoryCount)
		}

		String liferayLXCRepositoryPath = project.getProperty("lr.docker.environment.liferay-lxc.repository.path")

		if (liferayLXCRepositoryPath != null) {
			this.liferayLXCRepositoryPath = liferayLXCRepositoryPath
		}

		String liferayUserPassword = project.getProperty("lr.docker.environment.liferay.user.password")

		if (liferayUserPassword != null) {
			this.liferayUserPassword = liferayUserPassword
		}

		String lxcBackupOnePassword = project.getProperty("lr.docker.environment.lxc.backup.1password")

		if ((lxcBackupOnePassword != null) && (lxcBackupOnePassword.trim().length() > 0)) {
			this.lxcBackupPassword = project.ext.waitForCommand("op item get ${lxcBackupOnePassword} --fields password --reveal")
		}
		else {
			String lxcBackupPassword = project.getProperty("lr.docker.environment.lxc.backup.password")

			if (lxcBackupPassword != null) {
				this.lxcBackupPassword = lxcBackupPassword
			}
		}

		String namespace = project.getProperty("lr.docker.environment.namespace")

		if (namespace != null) {
			this.namespace = namespace
		}

		List services = project.properties.findAll {
			it.key =~ /^lr.docker.environment.service.enabled\[\w+\]$/
		}.findAll {
			it.value =~ /true|1/
		}.collect {
			it.key.substring(it.key.indexOf("[") + 1, it.key.indexOf("]"))
		}

		if (!services.isEmpty()) {
			this.services = services
		}

		this.liferayDockerImageId = "${this.namespace.toLowerCase()}-liferay"

		String[] databasePartitioningCompatibleServiceNames = ["mysql", "postgres"]
		File projectDir = project.projectDir as File

		this.useLiferay = this.services.contains("liferay")

		this.useClustering = this.useLiferay && this.clusterNodes > 0

		ConfigurableFileTree dockerComposeFileTree = project.fileTree(projectDir) {
			include "**/service.*.yaml"

			if (this.useClustering) {
				include "**/clustering.*.yaml"
			}

			if (this.useLiferay) {
				include "**/liferay.*.yaml"
			}

			if (this.databasePartitioningEnabled) {
				if (!this.services.any {databasePartitioningCompatibleServiceNames.contains(it)}) {
					throw new GradleException("Database partitioning must be used with one of these databases: ${databasePartitioningCompatibleServiceNames}")
				}

				include "**/database-partitioning.*.yaml"
			}
		}

		List<String> serviceComposeFiles = this.services.collect {
			String serviceName ->

			FileTree matchingFileTree = dockerComposeFileTree.matching {
				include "**/*.${serviceName}.yaml"
			}

			if (matchingFileTree.isEmpty()) {
				List<String> possibleServices = dockerComposeFileTree.findAll{
					it.name.startsWith("service.")
				}.collect {
					it.name.substring("service.".length(), it.name.indexOf(".yaml"))
				}

				throw new GradleException(
					"The service '${serviceName}' does not have a matching service.*.yaml file. Possible services are: ${possibleServices}");
			}

			matchingFileTree.getFiles()
		}.flatten().collect {
			projectDir.relativePath(it)
		}

		this.composeFiles.addAll(serviceComposeFiles)

		this.environmentMap.put "DATA_DIRECTORY", this.dataDirectory
		this.environmentMap.put "DATABASE_NAME", this.databaseName
		this.environmentMap.put "NAMESPACE", this.namespace

		if (this.useClustering) {
			this.environmentMap.put "LIFERAY_CLUSTER_NODES", this.clusterNodes
		}

		if (this.useLiferay) {
			this.environmentMap.put "LIFERAY_IMAGE_NAME", this.liferayDockerImageId
		}

		this.environmentMap.put("COMPOSE_FILE", this.composeFiles.join(File.pathSeparator))
		this.environmentMap.put("COMPOSE_PROJECT_NAME", this.namespace.toLowerCase())

		project.file('.env').withOutputStream {
			BufferedOutputStream envFileOutputStream ->

			this.environmentMap.forEach {
				key, value ->

				envFileOutputStream << key << "=" << value << "\n"
			}
		}

		this.environmentMap = environmentMap.asImmutable()
	}

	static List toList(String s) {
		return s.trim().split(",").grep()
	}

	public boolean clearVolumeData = false
	public int clusterNodes = 0
	public List<String> composeFiles = new ArrayList<String>()
	public String databaseName = "lportal"
	public boolean databasePartitioningEnabled = false
	public String dataDirectory = "data"
	public boolean documentLibraryFileListOnly = false
	public Map<String, String> environmentMap = [:]
	public List<String> hotfixURLs = new ArrayList<String>()
	public String liferayDockerImageId = ""
	public int liferayLXCEnvironmentHistoryCount = 5
	public String liferayLXCRepositoryPath = ""
	public String liferayUserPassword = "test"
	public String lxcBackupPassword = ""
	public String namespace = "lrswde"
	public List<String> services = new ArrayList<String>()
	public boolean useClustering = false
	public boolean useLiferay = false

	@Override
	public String toString() {
		return "${this.class.declaredFields.findAll{ !it.synthetic && !it.name.toLowerCase().contains("password") }*.name.collect { "${it}: ${this[it]}" }.join("\n")}"
	}
}