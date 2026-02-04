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

		String lxcRepositoryPathEnvironmentVariable = System.env["LXC_REPOSITORY_PATH"]

		if ((lxcRepositoryPathEnvironmentVariable != null) && !lxcRepositoryPathEnvironmentVariable.isEmpty()) {
			File lxcRepositoryPath = project.file(lxcRepositoryPathEnvironmentVariable)

			if (!lxcRepositoryPath.exists()) {
				lxcRepositoryPathEnvironmentVariable = null
			}
		}

		if ((lxcRepositoryPathEnvironmentVariable == null) || lxcRepositoryPathEnvironmentVariable.isEmpty()) {
			File defaultLXCRepositoryPath = new File(System.getProperty("user.home"), "dev/projects/liferay-lxc")

			if (defaultLXCRepositoryPath.exists()) {
				lxcRepositoryPathEnvironmentVariable = defaultLXCRepositoryPath.getAbsolutePath()
			}
		}

		if ((lxcRepositoryPathEnvironmentVariable != null) && !lxcRepositoryPathEnvironmentVariable.isEmpty()) {
			this.lxcRepositoryPath = lxcRepositoryPathEnvironmentVariable
		}

		String liferayUserPasswordProperty = project.findProperty("lr.docker.environment.liferay.user.password")

		if (liferayUserPasswordProperty != null) {
			this.liferayUserPassword = liferayUserPasswordProperty
		}

		String dataDirectoryProperty = project.findProperty("lr.docker.environment.data.directory")

		if (dataDirectoryProperty != null && dataDirectory.length() > 0) {
			this.dataDirectory = dataDirectoryProperty
		}

		String dlStoreProperty = project.findProperty("lr.docker.environment.dl.store")

		if (dlStoreProperty != null && !dlStoreProperty.isEmpty()) {
			this.dlStore = dlStoreProperty
		}

		Map<String, String> dlStoreClassMap = [
			"advanced": "com.liferay.portal.store.file.system.AdvancedFileSystemStore",
			"db": "com.liferay.portal.store.db.DBStore",
			"s3": "com.liferay.portal.store.s3.S3Store",
			"simple": "com.liferay.portal.store.file.system.FileSystemStore"
		]

		this.dlStoreClass = dlStoreClassMap[this.dlStore]

		if (this.dlStoreClass == null) {
			throw new GradleException("${dlStore} is not a valid DLStore type. Valid types are: ${dlStoreClassMap.collect {it.key}}")
		}

		if (this.dlStore == "advanced") {
			this.dlStorePath = getRequiredProperty(project, "lr.docker.environment.dl.store.path")
		}

		if (this.dlStore == "s3") {
			this.s3AccessKey = getRequiredProperty(project, "lr.docker.environment.s3.access.key")
			this.s3BucketName = getRequiredProperty(project, "lr.docker.environment.s3.bucket.name")
			this.s3Endpoint = project.findProperty("lr.docker.environment.s3.endpoint")
			this.s3Region = getRequiredProperty(project, "lr.docker.environment.s3.region")
			this.s3SecretKey = getRequiredProperty(project, "lr.docker.environment.s3.secret.key")
		}

		String glowrootEnabledProperty = project.findProperty("lr.docker.environment.glowroot.enabled")

		if (glowrootEnabledProperty != null) {
			this.glowrootEnabled = glowrootEnabledProperty.toBoolean()
		}

		List hotfixURLs = this.toList(project.findProperty("lr.docker.environment.hotfix.urls"))

		if (!hotfixURLs.isEmpty()) {
			Map<String, List<String>> hotfixURLsMap = hotfixURLs.collect {
				String hotfixURL ->

				if (hotfixURL.startsWith("https://storage.cloud.google.com/")) {
					return "gs://${hotfixURL.substring("https://storage.cloud.google.com/".length())}"
				}

				return hotfixURL
			}.groupBy {
				String hotfixURL ->

				hotfixURL.startsWith("gs://")
			}

			this.gcpHotfixURLs = hotfixURLsMap[true] ?: []
			this.hotfixURLs = hotfixURLsMap[false] ?: []
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

		String recaptchaEnabledProperty = project.findProperty("lr.docker.environment.recaptcha.enabled")

		if (recaptchaEnabledProperty != null) {
			this.recaptchaEnabled = recaptchaEnabledProperty.toBoolean()
		}

		def webserverHostnamesProperty = project.findProperty("lr.docker.environment.web.server.hostnames").split(',')*.trim().findAll { it }

		if (webserverHostnamesProperty != null) {
			this.webserverHostnames = webserverHostnamesProperty.join(' ')
		}

		String webserverModSecurityEnabledProperty = project.findProperty("lr.docker.environment.web.server.modsecurity.enabled")

		if (webserverModSecurityEnabledProperty != null) {
			this.modSecurityEnabled = webserverModSecurityEnabledProperty.toBoolean()
		}

		String webserverProtocolProperty = project.findProperty("lr.docker.environment.web.server.protocol")

		if (webserverProtocolProperty != null) {
			if (!(webserverProtocolProperty == "http" || webserverProtocolProperty == "https")) {
				throw new GradleException("Please set \"lr.docker.environment.web.server.protocol\" as either \"http\" or \"https\".")
			}

			this.webserverProtocol = webserverProtocolProperty
		}

		String yourKitEnabledProperty = project.findProperty("lr.docker.environment.yourkit.enabled")

		if (yourKitEnabledProperty != null) {
			this.yourKitEnabled = yourKitEnabledProperty.toBoolean()
		}

		String yourKitUrlProperty = project.findProperty("lr.docker.environment.yourkit.url")

		if (yourKitUrlProperty != null) {
			this.yourKitUrl = yourKitUrlProperty
		}

		String mediaPreviewEnabledProperty = project.findProperty("lr.docker.environment.media.preview.enabled")

		if (mediaPreviewEnabledProperty != null) {
			this.mediaPreviewEnabled = mediaPreviewEnabledProperty
		}

		this.useLiferay = this.services.contains("liferay")

		this.useClustering = this.useLiferay && this.clusterNodes > 0

		if (this.services.contains("db2")) {
			this.databaseType = "db2"
			this.useDatabase = true
			this.useDatabaseDB2 = true
		}

		if (this.services.contains("mariadb")) {
			this.databaseType = "mariadb"
			this.useDatabase = true
			this.useDatabaseMariaDB = true
		}

		if (this.services.contains("mysql")) {
			this.databaseType = "mysql"
			this.useDatabase = true
			this.useDatabaseMySQL = true
		}

		if (this.services.contains("postgres")) {
			this.databaseType = "postgres"
			this.useDatabase = true
			this.useDatabasePostgreSQL = true
		}

		if (this.services.contains("sqlserver")) {
			this.databaseType = "sqlserver"
			this.useDatabase = true
			this.useDatabaseSQLServer = true
		}

		if (this.services.contains("webserver")) {
			this.useWebserver = true
		}

		if (this.dockerImageLiferay.contains("7.4") || this.dockerImageLiferay.contains(".q")) {
			this.is74OrQuarterly = true
		}

		File projectDir = project.projectDir as File
		String[] databasePartitioningCompatibleServiceNames = ["mysql", "postgres"]

		ConfigurableFileTree dockerComposeFileTree = project.fileTree("compose-recipes") {
			include "**/service.*.yaml"

			if (useClustering) {
				include "**/clustering.*.yaml"
			}

			if (glowrootEnabled) {
				include "**/glowroot.*.yaml"
			}

			if (useLiferay) {
				include "**/liferay.*.yaml"
			}

			if (recaptchaEnabled) {
				include "**/recaptcha.*.yaml"
			}

			if (this.databasePartitioningEnabled) {
				if (!this.services.any {databasePartitioningCompatibleServiceNames.contains(it)}) {
					throw new GradleException("Database partitioning must be used with one of these databases: ${databasePartitioningCompatibleServiceNames}")
				}

				include "**/database-partitioning.*.yaml"
			}

			if (this.dlStore) {
				if (this.dlStore == "advanced") {
					include "**/dlstore.liferay.yaml"
				}

				if (this.dlStore == "s3") {
					include "**/s3store.liferay.yaml"
				}
			}

			if (this.yourKitEnabled) {
				include "**/yourkit.liferay.yaml"

				if (useClustering) {
					include "**/yourkit-clustering.liferay.yaml"
				}
			}

			if (mediaPreviewEnabled) {
				if (this.is74OrQuarterly) {
					include "**/ffmpeg.liferay.yaml"
				}
				else {
					include "**/xuggler.liferay.yaml"
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

	static Object getRequiredProperty(Project project, String property) {
		try {
			return project.getProperty(property)
		}
		catch (MissingPropertyException missingPropertyException) {
			throw new GradleException("Missing required property: ${property}", missingPropertyException)
		}
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
	public String databaseType = ""
	public boolean databasePartitioningEnabled = false
	public String dataDirectory = "data"
	public Map<String, String> defaultCompanyVirtualHost = null
	public String dlStore = ""
	public String dlStoreClass = ""
	public String dlStorePath = null
	public String dockerImageLiferay = null
	public boolean dockerImageLiferayDXP = false
	public List<String> gcpHotfixURLs = new ArrayList<String>()
	public boolean glowrootEnabled = false
	public List<String> hotfixURLs = new ArrayList<String>()
	public boolean is74OrQuarterly = false
	public boolean isARM = false
	public String liferayDockerImageId = ""
	public String liferayUserPassword = "test"
	public String lxcBackupPassword = null
	public String lxcEnvironmentName = null
	public String lxcRepositoryPath = null
	public boolean mediaPreviewEnabled = false
	public boolean modSecurityEnabled = false
	public String namespace = null
	public String product = null
	public boolean recaptchaEnabled = false
	public String s3AccessKey = null
	public String s3BucketName = null
	public String s3Endpoint = null
	public String s3Region = null
	public String s3SecretKey = null
	public List<String> services = new ArrayList<String>()
	public boolean useClustering = false
	public boolean useDatabase = false
	public boolean useDatabaseDB2 = false
	public boolean useDatabaseMariaDB = false
	public boolean useDatabaseMySQL = false
	public boolean useDatabasePostgreSQL = false
	public boolean useDatabaseSQLServer = false
	public boolean useLiferay = false
	public boolean useWebserver = false
	public String webserverHostnames = "localhost"
	public String webserverProtocol = null
	public boolean yourKitEnabled = false
	public String yourKitUrl = "https://www.yourkit.com/download/docker/YourKit-JavaProfiler-2025.3-docker.zip"

	@Override
	public String toString() {
		return "${this.class.declaredFields.findAll{ Field field -> !field.synthetic && !field.name.toLowerCase().contains("password") }*.name.collect { String fieldName -> "${fieldName}: ${this[fieldName]}" }.join("\n")}"
	}
}