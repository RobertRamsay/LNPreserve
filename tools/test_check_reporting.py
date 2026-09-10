import unittest
from run_checks import classify

class ReportingTests(unittest.TestCase):
 def test_early_failure_leaves_downstream_not_run(self):
  self.assertEqual(classify('LN_TEST_START:first\nLN_TEST_FAIL:first:exception\n',['first','saves','runtime']),{'first':'failed','saves':'not_run','runtime':'not_run'})
 def test_success_requires_completion(self):
  self.assertEqual(classify('LN_TEST_START:first\nLN_TEST_PASS:first\nLN_TEST_START:saves\n',['first','saves','runtime']),{'first':'passed','saves':'failed','runtime':'not_run'})
 def test_failure_overrides_a_previous_pass(self):
  self.assertEqual(classify('LN_TEST_PASS:runtime\nLN_TEST_FAIL:runtime\n',['runtime']),{'runtime':'failed'})

if __name__=='__main__':unittest.main()
