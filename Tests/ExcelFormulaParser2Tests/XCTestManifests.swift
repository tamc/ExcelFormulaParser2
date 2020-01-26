import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ExcelFormulaParser2Tests.allTests),
    ]
}
#endif
