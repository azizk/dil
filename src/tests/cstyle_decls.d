// This file is related to the FIXME note in parseVariableOrFunction().

// Some notes:
// When innerType is CFunc, then parseAsFunc.
// innerType := CFunc | Pointer | Array | null

// func: btype (null)(params)         ok suffix=NO
// var: btype (null)                     suffix=YES
// var: btype (null)[](params)           suffix=YES
// var: btype (null)[]                   suffix=YES
// depends: btype (inntype)(params)   ok suffix=YES
// depends: btype (inntype)[](params) ok suffix=YES
// depends: btype (inntype)           ok suffix=YES
// depends: btype (inntype)[]         ok suffix=YES


// Function and variable declarations:

int ((id))(bool)
{} // Func

int (id);

int (id)[](bool);

int (id)[];



int (*id)(bool);

int (*id);

int (*id)[](bool);

int (*id)[];



int (*(id))(bool);

int (*id());

int (*id())[](bool);

int (*id())[];

int func();
