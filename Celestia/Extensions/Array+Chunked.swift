//
//  Array+Chunked.swift
//  Celestia
//
//  Array extension for splitting into chunks
//  Used for batch Firestore queries which have a limit of 10 items per 'in' query
//

import Foundation

extension Array {
    /// Splits array into chunks of specified size
    /// Useful for Firestore 'in' queries which have a limit of 10 items
    ///
    /// - Parameter size: The maximum size of each chunk
    /// - Returns: An array of arrays, where each inner array has at most `size` elements
    ///
    /// Example:
    /// ```swift
    /// let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    /// let chunks = numbers.chunked(into: 3)
    /// // Result: [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11]]
    /// ```
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
