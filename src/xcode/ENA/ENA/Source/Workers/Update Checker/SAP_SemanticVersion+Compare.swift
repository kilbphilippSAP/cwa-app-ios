import Foundation

extension SAP_Internal_SemanticVersion: Comparable {
	static func < (lhs: SAP_Internal_SemanticVersion, rhs: SAP_Internal_SemanticVersion) -> Bool {
		if lhs.major != rhs.major {
			return lhs.major < rhs.major
		}
		if lhs.minor != rhs.minor {
			return lhs.minor < rhs.minor
		}
		if lhs.patch != rhs.patch {
			return lhs.patch < rhs.patch
		}
		return false
	}
}
