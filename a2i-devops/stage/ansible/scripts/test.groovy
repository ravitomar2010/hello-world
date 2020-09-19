

def sout = new StringBuilder(), serr = new StringBuilder()
def proc = 'aws iam list-users --profile stage --query Users[*].UserName'.execute()
proc.consumeProcessOutput(sout, serr)
proc.waitForOrKill(2000)

def values = "$sout".split("\n")
def count=1

//println values

def parameters=[]
values.each {
		//println "${it}"
	     val=("${it}".split(",")[0].toString())
	     if( val != '[' && val != ']' && val.contains('@')){
             		parameters.add(val.split('"')[1])
		}
            }
println parameters
parameters

