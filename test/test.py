#Print factorial of a number
 
def fact(n):
    if n==1:
        return 1
    else: 
        n=n * fact(n-1)
    return n
 
result=fact(6)
print(result)
 
if True:
    print("Should give a code smell")
elif False:
    print("should give 2 code smells now")
 
def add(a,b):
    #result = a+b
    return a+b
 
# Addition of 2 numbers
def addition(c,d):
    return c+d
 
add(1,2)
addition(3)
