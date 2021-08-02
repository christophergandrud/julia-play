# Examples for Workflow-for-Python-Package-Development

"""
Non-batch workflow for t-test
"""
import numpy as np
import scipy as sp
from scipy import stats

# Generate two random samples from the standard normal distribution
sample_a = np.random.randn(1000)
sample_b = np.random.randn(1000)

# T-test of sample_a vs sample_b
t_stat, p_value = sp.stats.ttest_ind(sample_a, sample_b)

"""
docstring example 
"""

def add_two(x:int) -> int:
    """
    Add two to an integer
    
    Parameters
    ----------
   	x: int
   		An integer to add 2 to.
   	
   	Returns
   	-------
   	An integer that is x + 2.
   	
   	Examples
   	--------
   	>>> add_two(10)
    12
    """
    return x + 2

