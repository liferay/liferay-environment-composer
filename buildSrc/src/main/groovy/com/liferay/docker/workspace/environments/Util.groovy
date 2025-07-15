package com.liferay.docker.workspace.environments

class Util {

	public static String fixReleaseKey(String releaseKey) {
		String result = releaseKey

		boolean is2024 = releaseKey.startsWith("dxp-2024.")
		boolean isQ1 = releaseKey.contains(".q1.")
		boolean isQuarterly = releaseKey.contains(".q")

		if (releaseKey.endsWith("-lts")) {
			if (!isQuarterly || !isQ1 || is2024) {
				return releaseKey.substring(0, releaseKey.length() - 4)
			}
		}
		else {
			if (isQuarterly && isQ1 && !is2024) {
				return releaseKey + "-lts"
			}
		}

		return releaseKey
	}

}