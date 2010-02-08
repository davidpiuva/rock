import ../../middle/[FunctionDecl, FunctionCall, TypeDecl, Argument, Type, Expression, InterfaceDecl]
import Skeleton, FunctionDeclWriter

FunctionCallWriter: abstract class extends Skeleton {
    
    /** @see FunctionDeclWriter */
    write: static func ~functionCall (this: This, fCall: FunctionCall) {
        //"|| Writing function call %s (expr = %s)" format(fCall name, fCall expr ? fCall expr toString() : "(nil)") println()

        if(!fCall ref) {
            Exception new(This, "Trying to write unresolved function %s\n" format(fCall toString())) throw()
        }
        fDecl : FunctionDecl = fCall ref
        
        FunctionDeclWriter writeFullName(this, fDecl)
        if(!fDecl isFinal && fCall getName() == "super") {
			current app("_impl")
        }
        current app('(')
        isFirst := true
        
        /* Step 1: write this, if any */
        if(!fDecl isStatic() && fCall expr) {
            isFirst = false
            callType := fCall expr getType()
            declType := fDecl owner getInstanceType()
            
            // TODO maybe check there's some kind of inheritance/compatibility here?
            // or in the tinker phase?
            if(!(callType equals(declType))) {
                current app("("). app(declType). app(") ")
            }
            
            current app(fCall expr) 
        }
    
        /* Step 2 : write generic return arg, if any */
        if(fDecl getReturnType() isGeneric()) {
            if(isFirst) {
                isFirst = false
            } else {
                current app(", ")
            }
            
            retArg := fCall getReturnArg()
            if(retArg) {
                if(retArg getType() isGeneric()) {
                    current app(retArg)
                } else {
                    // FIXME hardcoding uint8_t is probably a bad idea. Ain't it?
                    current app("(uint8_t*) &("). app(retArg). app(")")
                }
            } else {
                current app("NULL")
            }
        }
    
        /* Step 3 : write generic type args */
        i := 0
        for(typeArg in fCall typeArgs) {
            ghost := false
            for(arg in fDecl args) {
                if(arg getName() == fDecl typeArgs get(i) getName()) {
                    ghost = true
                    break
                }
            }
            
            if(!ghost) {
                if(isFirst) isFirst = false
                else        current app(", ")
                // FIXME: it's really ugly to hardcode class
                // it should be resolved once and for all in Resolver and used from there.
                current app("(lang__Class*)"). app(typeArg)
            }
            
            i += 1
        }
        
        /* Step 4 : write real args */
        i = 0
        for(arg: Expression in fCall args) {
            if(isFirst) {
                isFirst = false
            } else {
                current app(", ")
            }
            
            declArg : Argument = null
            if(i < fDecl args size())                         declArg = fDecl args get(i)
            if(declArg != null && declArg instanceOf(VarArg)) declArg = null
            
            isInterface := declArg != null && declArg getType() getRef() instanceOf(InterfaceDecl)
            
            if(declArg != null) {
                if(isInterface) {
                    printf("%s is a call, which arg %s is of interface type.\n", fCall toString(), declArg toString())
                    iDecl := declArg getType() getRef() as InterfaceDecl
                    //current app("(struct "). app(iDecl getFatType() getInstanceType()). app(") {").
                    current app("(struct _"). app(iDecl getFatType() getInstanceType()). app(") {").
                        app(arg getType() getName()). app("__impl__"). app(iDecl getName()). app("_class(), (lang__Object*)")
                }
                
                if(declArg getType() isGeneric()) {
                    current app("(uint8_t*) ")
                } else if(arg getType != null && declArg getType() != null && arg getType() inheritsFrom(declArg getType())) {
                    //printf("%s inherits from %s, casting!\n", arg getType() toString(), declArg getType() toString())
                    current app("("). app(declArg getType()). app(")")
                }
            }
            
            arg accept(this)
            
            if(isInterface) current app("}")
            
            i += 1
        }
        current app(')')
        
        /* Step 4 : write exception handling arguments */
        // TODO
    }
    
}

