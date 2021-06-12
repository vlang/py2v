# Basic usage
```bash
./py2v <file1>.py <file2>.v
```
This should read file1.py and make a separate file2.v file. Compile the code with:  
```bash
# if v is on PATH
v <name of file 2>.v
```
or  
```bash
# if v is not on path
<path to v> <name of file2>.v
```
  
  
# More options
 Using `-` as the output argument will output the transpiled code to stdout.
  
  
