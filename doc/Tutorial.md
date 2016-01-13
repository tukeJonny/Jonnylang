チュートリアル

１．Jonny言語とは

　tukejonnyがトップダウン構文解析を学ぶ過程で作られた闇言語。未実装なところが多いので、実用はきつそう。どうか、温かい目で見守ってください。

２．変数宣言

　変数宣言は、ローカル変数宣言とグローバル変数宣言の２種類がある。グローバル変数宣言は以下のとおり。

```|Jonny|
global val = “Jonny”

```

ローカル変数宣言は以下のとおり。

```|Jonny|
local val = “J” + “o” + “n” + “n” + “y”

```

３．条件分岐文の実行

　条件分岐はif文のみで構成されるパターン、else文がその後に続くパターン、そうではなく、elif文がいくつか続き、else文が最後にくるパターン等があります

①if

```|Jonny|
if(true) {
  print “I like renchon.”
}

```

②if-else

```|Jonny|
global a = 1
global b = 2
if(a == b) {
  print “equal”
} else {
  print “not equal”
}

```

③if-elif*-else

```|Jonny|
global a = 3
global b = 4

if(a > b) {
  print “greater than b”
} elif(a < b) {
  print “less than b”
} else {
  print “equal”
}
```


４．繰り返し文の実行

　繰り返し文はwhile文のみ。

```|Jonny|
global n = 3
while(n >= 0) {
  print “kadai owaranai”
  n -= 1
}

```

５．標準入力

　標準入力から変数に値を代入するために、read文を用いる。

```|Jonny|
global input = -1

read input

if(input < 0) {
  print “Oh,,, Please input”
} else {
  print input
}
```

６．標準出力

　標準出力を行うには、print文を用いる。

```|Jonny|
print “Hello renchon”
```

７．関数定義

　関数定義を行うには、def文を用いる

```|Jonny|
def sampleFunc(arg) {
  print arg
}
```

８．関数呼び出し

　関数呼び出しは、以下のように引数を渡して呼び出せる。

```|Jonny|
sampleFunc(“Hello!”)
```

９．Hello World

　Jonny言語でHello Worldを出力するためのプログラムは以下のようになる。

```|Jonny|
print “Hello World”
```

１０．n個のfibonacci数を出す

```|Jonny|
global n = 1
global a = 1
global b = 1

def header() {
	print "***** This is sample program *****"
	print "***** This program outputs 1-nth fibonacci number *****"
}

def fib(arg1, arg2, num) {
	print arg1
	print arg2
	while(num >= 0) {
		local c = arg1 + arg2
		print c
		arg1 = arg2
		arg2 = c
		num -= 1
	}
	return("Finished!")
}

header()
print "Please input n(output n fibonacci number)"
read n
if(n == 1) {
	print a
} elif(n == 2) {
	print a
	print b
} else {
	print fib(a, b, n-(2+1))
}
```
