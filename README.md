# MiniServo for the Mac

This project is designed to be used with the mainline Servo branch:

    https://github.com/servo/servo

## Prerequisites

A fresh checkout and build of servo. For further information on building
Servo for OSX, please check:

https://github.com/servo/servo

After you checked out servo, installed its deps and were able to build, the
next step is to build the CEF port:

```
./mach build-cef [--release]
```

## How to build MiniServo

Start by checking out the repository and its submodules:

```
git clone https://github.com/pcwalton/miniservo-mac.git
cd miniservo-mac
git submodule update --init --recursive

#or
git clone --recursive https://github.com/pcwalton/miniservo-mac.git
```


Open the project in XCode and build (Product->Build or CMD + B). In case you
have build issues, double check if the submodules were really checked out.

## Run

Miniservo will require access to the 'resources' folder in servo checkout. For while,
copy or create a symbolic link to your Library folder:

```
cp -rp $SERVO_CHECKOUT/resources $HOME/Library/Developer/Xcode/DerivedData/MiniServo-cqxsspgatqbgifdcdvgjhrgbqygu/Build/Products/resources

```

By running miniservo (i.e. Product->Run or CMD + R), XCode will popup a dialog asking where
libcef is located. It should be in your servo checkout folder (i.e. servo/ports/cef/target/release/).

After this steps, enjoy running MiniServo in full parallel glory.
