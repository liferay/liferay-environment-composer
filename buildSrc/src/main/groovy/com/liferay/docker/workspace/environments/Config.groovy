package com.liferay.docker.workspace.environments

import java.util.regex.Pattern
import java.util.regex.Matcher

import org.gradle.api.Project
import org.gradle.api.file.ConfigurableFileTree
import org.gradle.api.file.FileTree
import org.gradle.api.GradleException


class Config {

	public Config(Project project) {
		this.project = project

		Integer clusterNodes = project.getProperty("lr.docker.environment.cluster.nodes") as Integer

		if (clusterNodes != null) {
			this.clusterNodes = clusterNodes
		}

		this.composeFiles.add("docker-compose.yaml")

		this.composeFiles.addAll(this.toList(project.getProperty("lr.docker.environment.compose.files")))

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

		List hotfixURLs = this.toList(project.getProperty("lr.docker.environment.hotfix.urls"))

		if (!hotfixURLs.isEmpty()) {
			this.hotfixURLs = hotfixURLs
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

		def webserverHostnames = project.getProperty("lr.docker.environment.web.server.hostnames").split(',')*.trim().findAll { it }

		if (webserverHostnames != null) {
			this.webserverHostnames = webserverHostnames.join(' ')
		}
	}

	static List toList(String s) {
		return s.trim().split(",").grep()
	}

	public Project project

	public int clusterNodes = 0
	public List<String> composeFiles = new ArrayList<String>()
	public String databaseName = "lportal"
	public boolean databasePartitioningEnabled = false
	public String dataDirectory = "data"
	public List<String> hotfixURLs = new ArrayList<String>()
	public String liferayDockerImageId = ""
	public String namespace = "lrswde"
	public List<String> services = new ArrayList<String>()
	public String webserverHostnames = "localhost"

	@Override
	public String toString() {

		return """

Config:
------------------------
clusterNodes: ${clusterNodes}
composeFiles: ${composeFiles}
databaseName: ${databaseName}
databasePartitioningEnabled: ${databasePartitioningEnabled}
dataDirectory: ${dataDirectory}
hotfixURLs: ${hotfixURLs}
liferayDockerImageId: ${liferayDockerImageId}
namespace: ${namespace}
services: ${services}
webserverHostnames: ${webserverHostnames}

"""
	}
}