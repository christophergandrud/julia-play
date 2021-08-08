# Workflow for Developing Python Packages for Distribution

Updated: 2021-08-08

## Why package?

Wrapping up our code into reusable Python packages allow us to take more full advantage of one of the great features of software: extensibility. It allows us to bundle up code that can be used again and again, often in novel extensions of the original use case. We can distribute our code more widely, using an index such as PyPI. Creating packages also encourages us to write more robust, better documented, and easy to understand code.  

## Key Elements of Robust Packaging

Your package is a piece of software that should enable you and your users to achieve some task. You should design it with the user's needs in mind. So, before you start, document these needs and design a package workflow that not only makes sense within the package, but also within the broader workflow that a user is likely using. 

> To design a useful package, have **empathy** for your users

Remember: you are writing code not so that it is easy for you to use and maintain, but so that it is easy for others to use and maintain.

In addition to a clear and meaningful workflow, a useful and robust package is (a) modular, (b) well documented, and (c) extensively and automatically tested. 

Strive for **modulatiry**. Writing functions that are small and specific--modular--enables easier testing, maintenence, and extensibility. The [unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy) can help guide our function design: 

> Make each [function] do one thing well.

The same rule holds for packages, make the package scope small and clearly defined. A really good reference to dig in deeper is John Ousterhout's [*A Philosophy of Software Design* (2018)](https://web.stanford.edu/~ouster/cgi-bin/book.php).

Make your package **easily interoperable**. Design your package to accept standard inputs from other packages. Expect its outputs to become inputs to other programs. The simplest inputs/outputs are text strings. Self explainable pandas data frames or CSVs (just formatted text strings) are likely good input/output format choices Python package that works with data.  

Don't forget to **document** your package such that someone who was not involved in the package development (and yourself in the future) can fully understand it. This includes documenting:

- the purpose of the package
- the workflow of the package with examples
- each function's purpose, usage, and outputs with examples
- each function parameter's description

If your package is well defined in scope and the functions are focused, then the documentation should be easy to write. If you find yourself struggling to write documentation, this is a red flag that your functions/package are too complex.[^doc-red-flag]

Don't forget to **test** your package.  [Test driven development](https://en.wikipedia.org/wiki/Test-driven_development)--where you write and automate the test for the correctness of your code before fully writing the code--enables you to create more robust code that is easier to maintain. It is more robust, because you have tests validating your code's correctness. It is more maintainable, because changes both to the package and its dependencies are automatically evaluated before deployment. Ideally your tests allow you to "fail fast" in that the tests fail close to the source of the problem. This makes the debugging process faster.

Take advantage of version control and CI/CD tools such as Git, GitHub, and GitHub actions. These tools allow you to develop new features while being confident that they only make it to the "release" version of the package once they have passed your tests.

## Implementation Details

Assuming we have a package purpose and workflow designed, these are important implementation details you'll need to create, test, and distribute your package. 

### File structure

First create a new directory for your package and commit it to some version control system such as GitHub. In this example, the package functions will be in the `mean_var.py` file or module. Imagine we are creating a package called **stats_batch**.[^package-name]  Our initial file structure for the **stats_batch** package could look like this:

```shell
stats_batch
├── CHANGELOG
├── .github
│   └── workflow
├── LICENSE
├── stats_batch
│   ├── __init__.py
│   └── mean-var.py
├── README.md
└── setup.py
└── tests
```

The `__init__.py` file is empty. It denotes the directory as a Python package. Use the **setuptools** package to create the `setup.py` file. This file contains key metadata for your package. For example:

```python
from setuptools import setup

setup(
    name='stats_batch',
    version='0.0.9000',    
    description='Find statistics (e.g. mean and variance) using batch updating algorithms',
    url='https://github.com/christophergandrud/batch-stats',
    author='Christopher Gandrud',
    author_email='christopher.gandrud@gmail.com',
    license='MIT',
    packages=['stats_batch'],
    install_requires=['numpy',
                      'scipy'                   
                      ],

    classifiers=[
        'Development Status :: 1 - Planning',
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: MIT License',  
        'Programming Language :: Python :: 3.5',
    ],
)
```

See the [Python Packaging project](https://packaging.python.org/tutorials/packaging-projects/) for details.  

#### Installing your package

Once you have these files in place, you can install your package. Go to the terminal. Make your package the working directory (this is assumed for all following terminal examples). Then use:

```bash
pip3 install .
```

### Documenting

#### README.md

The README.md file is the introduction to your package and package workflow. It should include at least the package's:

- purpose and context
- self-contained examples of the package's workflow and capabilities

#### Function documentation

Function documentation in Python is built from [docstrings](https://www.python.org/dev/peps/pep-0257/). For example:

```python
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
```

The full function documentation is included in the function definition and denoted by three double quotes. The first line of the docstring describes the purpose of the function. Then we document the function's one argument `x`, describe what the function returns, and provide examples. Users can access this documentation by calling `help(add_two)`. 

There are multiple style guides for Python docstrings. The [numpy/scipy style guide](https://numpydoc.readthedocs.io/en/latest/format.html) is a good one to use.

### Changelog

Each time you make a release of your package, you should document the changes in a CHANGELOG. 

### Testing

#### Type checking

In the docstring example above, we defined the functions arguments and what it returns:

```python
def add_two(x:int) -> int:
```

Notice that we defined the types of the parameters--`int`--and what the function returns--also `int`. Each time a user runs the fuction, Python will check to ensure that the inputs and outputs are integers.[^types] Type checking is useful for:

- making how the function works in terms of inputs and outputs more obvious. This enables users to more easily use and extend the function to new use cases.
- catches problems sooner. A major source of errors is passing data to a function that it does not know how to handle. Type checking helps catch this immediately.  

#### Test files

As you develop your package, build its suite of automated tests. To do this, create a directory called *tests*. In this directory, place Python files that begin with `test`. For example, here is `test_batch_mean.py`

```python
import stats_batch as sb
import numpy as np

# Test batch_mean returns the mean if prior_mean and prior_sample_size are missing
def test_batch_mean_missing_prior_mean_prior_sample_size():
    x = list(range(1, 100))
    assert sb.batch_mean(x) == np.mean(x) 
```

Then in the terminal, use the `pytest` function (from the **pytest** package) to run all of the tests:

```bash
pytest
```

Note: all of the test function names need to begin with `test_`.

#### Code coverage

You can get an overview of how much of your code is covered by tests with the **coverage** package. Code coverage provide a quick indication of where there might be blind spots in your current set of tests. 

Here is an example of how to use **coverage** in your terminal:

```bash
# Run tests and record code coverage
coverage run -m pytest

# Show report
coverage report
```

You can also create a badge to report your code coverage, for example in the README, with the **coverage-bage** package. In the terminal:

```bash
coverage-badge -o coverage.svg -f
```

Then in your README add: 

```markdown
![code-coverage](coverage.svg)
```

In the rendered version of the README, e.g. on GitHub, you will now have see a badge with the code coverage percentage for the package.

#### Branch control and releases

Your package should be in a version control system like GitHub. The *main* branch should be your "protected branch". Develop and test new code in other branches. Only merge code into the *main* branch after it has passed the automated tests and (if it is headed for production) review by a peer. This is sometimes called the "four eyes" principle. On GitHub you can enforce this discipline with [branch control](https://docs.github.com/en/github/administering-a-repository/defining-the-mergeability-of-pull-requests/managing-a-branch-protection-rule).

Rules of thumb for this process include:

- Commit and merge often. Avoid trying to work on and then merge large changes. Trying to merge in large changes is highly likely to create bugs that are hard to debugg and make it difficult to collaboarte on a project as it will create hard to disentangle merge conflicts.
- All code changes should come with new tests. If it is a new feature, you need a test for the new feature. If it is a fix for a bug that was not caught in previous automated tests, add a new test to cover this bug, so you can avoid it in the future.

### CI/CD 

The public GitHub has a really good built in CI/CD platform called [GitHub Actions](https://github.com/features/actions). This will build your package and run all of the tests (if you set it up to) on multiple platforms. In your package, add the directory *.github/workflow*. Then place an Actions YAML file in this directory. [Here](https://github.com/christophergandrud/stats_batch/blob/main/.github/workflows/test-stats-batch.yaml) is an example to get started. Each time you push a commit, GitHub will run your tests. Click on the *Actions* tab on your repo's GitHub website to see the outcome of the tests. 

### Distributing

Once you have your package built and tested, you can distribute it through the [PyPI](https://pypi.org/) package index. The [official tutorial](https://packaging.python.org/tutorials/packaging-projects/#generating-distribution-archives) has easy to follow instructions for how to do this. It is a good idea to try it out on the [test index](https://test.pypi.org/) first.

Assuming:

- your package pasts its tests

- you have a (test) PyPI account and API token

- have the **build** and **twine** packages installed,

  follow a workflow like this in your terminal:

```shell
# Build package
python3 -m build

# Upload built package to testpypi
python3 -m twine upload --repository testpypi dist/*

```

If successful, you should be given a URL for the packages directory.

You could also include the build and publish process as part of your CI/CD pipeline. For more information see [here](https://github.com/pypa/gh-action-pypi-publish). 

[^doc-red-flag]: This is one of the red flags highlighted in Ousterhout's (2018) highly recommended *A Philosophy of Software Design*. 
[^package-name]: The package I created while writing this tutorial is called **stats-batch** and can be found [here](https://github.com/christophergandrud/stats_batch).
[^types]: See [here](https://docs.python.org/3/library/stdtypes.html) for a full list of Python's built in types.

