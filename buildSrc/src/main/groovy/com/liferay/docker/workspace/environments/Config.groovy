package com.liferay.docker.workspace.environments

import java.lang.reflect.Field

import java.util.regex.Pattern
import java.util.regex.Matcher

import org.gradle.api.Project
import org.gradle.api.file.ConfigurableFileTree
import org.gradle.api.file.FileTree
import org.gradle.api.GradleException


class Config {

	public Config(Project project) {
		this.project = project

		Integer clusterNodesProperty = project.findProperty("lr.docker.environment.cluster.nodes") as Integer

		if (clusterNodesProperty != null) {
			this.clusterNodes = clusterNodesProperty
		}

		this.composeFiles.add("docker-compose.yaml")

		this.composeFiles.addAll(this.toList(project.findProperty("lr.docker.environment.compose.files")))

		String clearVolumeData = project.findProperty("lr.docker.environment.clear.volume.data")

		if (clearVolumeData != null) {
			this.clearVolumeData = clearVolumeData.toBoolean()
		}

		String databaseNameProperty = project.findProperty("lr.docker.environment.database.name")

		if (databaseNameProperty != null) {
			this.databaseName = databaseNameProperty
		}

		String databasePartitioningEnabledProperty = project.findProperty("lr.docker.environment.database.partitioning.enabled")

		if (databasePartitioningEnabledProperty != null) {
			this.databasePartitioningEnabled = databasePartitioningEnabledProperty.toBoolean()
		}

		String lxcBackupPasswordProperty = project.findProperty("lr.docker.environment.lxc.backup.password")

		if (lxcBackupPasswordProperty != null) {
			this.lxcBackupPassword = lxcBackupPasswordProperty
		}

		String lxcEnvironmentNameProperty = project.findProperty("lr.docker.environment.lxc.environment.name")

		if (lxcEnvironmentNameProperty != null) {
			this.lxcEnvironmentName = lxcEnvironmentNameProperty
		}

		String lxcRepositoryPathProperty = project.findProperty("lr.docker.environment.lxc.repository.path")

		if (lxcRepositoryPathProperty != null) {
			this.lxcRepositoryPath = lxcRepositoryPathProperty
		}

		String liferayUserPasswordProperty = project.findProperty("lr.docker.environment.liferay.user.password")

		if (liferayUserPasswordProperty != null) {
			this.liferayUserPassword = liferayUserPasswordProperty
		}

		String dataDirectoryProperty = project.findProperty("lr.docker.environment.data.directory")

		if (dataDirectoryProperty != null && dataDirectory.length() > 0) {
			this.dataDirectory = dataDirectoryProperty
		}

		String glowrootEnabledProperty = project.findProperty("lr.docker.environment.glowroot.enabled")

		if (glowrootEnabledProperty != null) {
			this.glowrootEnabled = glowrootEnabledProperty.toBoolean()
		}

		List hotfixURLs = this.toList(project.findProperty("lr.docker.environment.hotfix.urls"))

		if (!hotfixURLs.isEmpty()) {
			this.hotfixURLs = hotfixURLs
		}

		String arch = System.getProperty("os.arch")

		if (arch.contains("arm") || arch.contains("aarch")) {
			this.isARM = true
		}

		String namespaceProperty = project.findProperty("lr.docker.environment.namespace")

		if (namespaceProperty != null) {
			this.namespace = Util.toDockerSafeName(namespaceProperty)
		}
		else {
			this.namespace = Util.toDockerSafeName(this.project.name)
		}

		List services = project.properties.findAll {
			Map.Entry<String, String> property ->

			property.key =~ /^lr.docker.environment.service.enabled\[\w+\]$/
		}.findAll {
			Map.Entry<String, String> serviceProperty ->

			serviceProperty.value =~ /true|1/
		}.collect {
			Map.Entry<String, String> serviceProperty ->

			serviceProperty.key.substring(serviceProperty.key.indexOf("[") + 1, serviceProperty.key.indexOf("]"))
		}

		if (!services.isEmpty()) {
			this.services = services
		}

		this.product = project.gradle.liferayWorkspace.product
		this.dockerImageLiferay = project.gradle.liferayWorkspace.dockerImageLiferay

		if (((this.product != null) && this.product.startsWith("dxp-")) ||
			((this.dockerImageLiferay != null) && this.dockerImageLiferay.startsWith("liferay/dxp:"))) {

			this.dockerImageLiferayDXP = true
		}

		this.liferayDockerImageId = "${this.namespace}-liferay"

		def webserverHostnamesProperty = project.findProperty("lr.docker.environment.web.server.hostnames").split(',')*.trim().findAll { it }

		if (webserverHostnamesProperty != null) {
			this.webserverHostnames = webserverHostnamesProperty.join(' ')
		}

		String yourKitEnabledProperty = project.findProperty("lr.docker.environment.yourkit.enabled")

		if (yourKitEnabledProperty != null) {
			this.yourKitEnabled = yourKitEnabledProperty.toBoolean()
		}

		String yourKitUrlProperty = project.findProperty("lr.docker.environment.yourkit.url")

		if (yourKitUrlProperty != null) {
			this.yourKitUrl = yourKitUrlProperty
		}

		this.useLiferay = this.services.contains("liferay")

		this.useClustering = this.useLiferay && this.clusterNodes > 0

		if (this.services.contains("db2")) {
			this.useDatabase = true
			this.useDatabaseDB2 = true
			this.dockerContainerDatabase = "${this.namespace}-database-db2"
		}

		if (this.services.contains("mariadb")) {
			this.useDatabase = true
			this.useDatabaseMariaDB = true
		}

		if (this.services.contains("mysql")) {
			this.useDatabase = true
			this.useDatabaseMySQL = true
			this.dockerContainerDatabase = "${this.namespace}-database-mysql"
		}

		if (this.services.contains("postgres")) {
			this.useDatabase = true
			this.useDatabasePostgreSQL = true
			this.dockerContainerDatabase = "${this.namespace}-database-postgres"
		}

		if (this.services.contains("webserver_http") && this.services.contains("webserver_https")) {
			throw new GradleException("Both HTTP and HTTPS are enabled for the webserver service. Only one protocol can be active at a time.")
		}

		this.useWebserverHttp = this.services.contains("webserver_http")

		this.useWebserverHttps = this.services.contains("webserver_https")

		File projectDir = project.projectDir as File
		String[] databasePartitioningCompatibleServiceNames = ["mysql", "postgres"]

		ConfigurableFileTree dockerComposeFileTree = project.fileTree("compose-recipes") {
			include "**/service.*.yaml"

			if (useClustering) {
				include "**/clustering.*.yaml"
			}

			if (useLiferay) {
				include "**/liferay.*.yaml"
			}

			if (this.databasePartitioningEnabled) {
				if (!this.services.any {databasePartitioningCompatibleServiceNames.contains(it)}) {
					throw new GradleException("Database partitioning must be used with one of these databases: ${databasePartitioningCompatibleServiceNames}")
				}

				include "**/database-partitioning.*.yaml"
			}

			if (this.yourKitEnabled) {
				include "**/yourkit.liferay.yaml"

				if (useClustering) {
					include "**/yourkit-clustering.liferay.yaml"
				}
			}
		}

		List<String> serviceComposeFiles = this.services.collect {
			String serviceName ->

			FileTree matchingFileTree = dockerComposeFileTree.matching {
				include "**/*.${serviceName}.yaml"
			}

			if (matchingFileTree.isEmpty()) {
				List<String> possibleServices = dockerComposeFileTree.findAll{
					File composeFile ->

					composeFile.name.startsWith("service.")
				}.collect {
					File serviceComposeFile ->

					serviceComposeFile.name.substring("service.".length(), serviceComposeFile.name.indexOf(".yaml"))
				}

				throw new GradleException(
					"The service '${serviceName}' does not have a matching service.*.yaml file. Possible services are: ${possibleServices}");
			}

			matchingFileTree.getFiles()
		}.flatten().collect {
			File serviceComposeFile ->

			projectDir.relativePath(serviceComposeFile)
		}

		this.composeFiles.addAll(serviceComposeFiles)
	}

	static List toList(String s) {
		if (s == null) {
			return []
		}

		return s.trim().split(",").grep()
	}

	public Project project

	public boolean clearVolumeData = false
	public int clusterNodes = 0
	public List<Map<String, String>> companyVirtualHosts = null
	public List<String> composeFiles = new ArrayList<String>()
	public String databaseName = "lportal"
	public boolean databasePartitioningEnabled = false
	public String dataDirectory = "data"
	public Map<String, String> defaultCompanyVirtualHost = null
	public String dockerContainerDatabase = null
	public String dockerImageLiferay = null
	public boolean dockerImageLiferayDXP = false
	public boolean glowrootEnabled = false
	public List<String> hotfixURLs = new ArrayList<String>()
	public boolean isARM = false
	public String liferayDockerImageId = ""
	public String liferayUserPassword = "test"
	public String lxcBackupPassword = null
	public String lxcEnvironmentName = null
	public String lxcRepositoryPath = null
	public String namespace = null
	public String product = null
	public List<String> services = new ArrayList<String>()
	public boolean useClustering = false
	public boolean useDatabase = false
	public boolean useDatabaseDB2 = false
	public boolean useDatabaseMariaDB = false
	public boolean useDatabaseMySQL = false
	public boolean useDatabasePostgreSQL = false
	public boolean useLiferay = false
	public boolean useWebserverHttp = false
	public boolean useWebserverHttps = false
	public String webserverHostnames = "localhost"
	public boolean yourKitEnabled = false
	public String yourKitUrl = "https://www.yourkit.com/download/docker/YourKit-JavaProfiler-2025.3-docker.zip"

	@Override
	public String toString() {
		return "${this.class.declaredFields.findAll{ Field field -> !field.synthetic && !field.name.toLowerCase().contains("password") }*.name.collect { String fieldName -> "${fieldName}: ${this[fieldName]}" }.join("\n")}"
	}
}