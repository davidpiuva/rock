import structs/[ArrayList, List], text/Buffer
import ../frontend/[Token, BuildParams, CommandLine]
import Visitor, Expression, FunctionDecl, Argument, Type, VariableAccess,
       TypeDecl, Node, VariableDecl, AddressOf, CommaSequence, BinaryOp,
       InterfaceDecl, Cast, NamespaceDecl, BaseType, FuncType, Return,
       TypeList
import tinker/[Response, Resolver, Trail, Errors]

/**
 * Every function call, member or not, is represented by this AST node.
 *
 * Member calls (ie. "blah" println()) have a non-null 'expr'
 *
 * Calls to functions with generic type arguments store the 'resolution'
 * of these type arguments in the typeArgs list. Until all type arguments
 * are resolved, the function call is not fully resolved.
 *
 * Calls to functions that have multi-returns or a generic return type
 * use returnArgs expression (secret variables that are references,
 * and are assigned to when the return happens.)
 *
 * @author Amos Wenger (nddrylliog)
 */
FunctionCall: class extends Expression {

    /**
     * Expression on which we call something, if any. Function calls
     * have a null expr, method calls have a non-null ones.
     */
    expr: Expression

    /** Name of the function being called. */
    name: String

    /**
     * If the suffix is non-null (ie it has been specified in the code,
     * via name~suffix()), it won't accept functions that have a different
     * suffix.
     *
     * If suffix is null, it'll just try to find the best match, no matter
     * the suffix.
     */
    suffix = null : String

    /**
     * Resolved declaration's type arguments. For example,
     * ArrayList<Int> new() will have 'Int' in its typeArgs.
     */
    typeArgs := ArrayList<Expression> new()

    /**
     * Calls to functions that have multi-returns or a generic return type
     * use returnArgs expression (secret variables that are references,
     * and are assigned to when the return happens.)
     */
    returnArgs := ArrayList<Expression> new()

    /**
     * Inferred return type of the call - might be different from ref's returnType
     * if it is generic, for example.
     */
    returnType : Type = null

    args := ArrayList<Expression> new()

    /**
     * The actual function declaration this call is calling.
     * Note that this makes rock almost a linker too - it effectively
     * knows the ins and outs of all your calls before it dares
     * generate C code.
     */
    ref = null : FunctionDecl

    /**
     * < 0 = not resolved (incompatible functions)
     * > 0 = resolved
     *
     * Score is determined in getScore(), depending on the arguments, etc.
     *
     * Function declarations that don't even match the name don't even
     * have a score.
     */
    refScore := INT_MIN

    /**
     * Create a new function call to the function '<name>()'
     */
    init: func ~funcCall (=name, .token) {
        super(token)
    }

    /**
     * Create a new method (member function) call to the function 'expr <name>()'
     */
    init: func ~functionCallWithExpr (=expr, =name, .token) {
        super(token)
    }

    setExpr: func (=expr) {}
    getExpr: func -> Expression { expr }

    setName: func (=name) {}
    getName: func -> String { name }

    setSuffix: func (=suffix) {}
    getSuffix: func -> String { suffix }

    accept: func (visitor: Visitor) {
        visitor visitFunctionCall(this)
    }

    /**
     * Internal method used to print a shitload of debugging messages
     * on a particular function - used in one-shots of hardcore debugging.
     *
     * Usually has 'name == "something"' instead of 'false' as
     * a return expression, when it's being used.
     */
    debugCondition: inline func -> Bool {
        false
    }

    /**
     * This method is being called by other AST nodes that want to suggest
     * a function declaration to this function call.
     *
     * The call then evaluates the score of the decl, and if it has a higher score,
     * stores it as its new best ref.
     */
    suggest: func (candidate: FunctionDecl) -> Bool {

        if(debugCondition()) "** [refScore = %d] Got suggestion %s for %s" format(refScore, candidate toString(), toString()) println()

        if(isMember() && candidate owner == null) {
            if(debugCondition()) printf("** %s is no fit!, we need something to fit %s\n", candidate toString(), toString())
            return false
        }

        score := getScore(candidate)
        if(score == -1) {
            if(debugCondition()) "** Score = -1! Aboort" println()
            return false
        }

        if(score > refScore) {
            if(debugCondition()) "** New high score, %d/%s wins against %d/%s" format(score, candidate toString(), refScore, ref ? ref toString() : "(nil)") println()
            refScore = score
            ref = candidate
            return score > 0
        }
        return false

    }

    resolve: func (trail: Trail, res: Resolver) -> Response {

        //printf("===============================================================\n")
        //printf("     - Resolving call to %s (ref = %s)\n", name, ref ? ref toString() : "(nil)")

        // resolve all arguments
        if(args size() > 0) {
            trail push(this)
            i := 0
            for(arg in args) {
                response := arg resolve(trail, res)
                if(!response ok()) {
                    trail pop(this)
                    return response
                }
                i += 1
            }
            trail pop(this)
        }

        // resolve our expr. e.g. in
        //     object doThing()
        // object is our expr.
        if(expr) {
            trail push(this)
            response := expr resolve(trail, res)
            trail pop(this)
            if(!response ok()) {
                if(res params veryVerbose) printf("Failed to resolve expr %s of call %s, looping\n", expr toString(), toString())
                return response
            }
        }

        // resolve all returnArgs (secret arguments used when we have
        // multi-return and/or generic return type
        for(i in 0..returnArgs size()) {
            returnArg := returnArgs[i]
            if(!returnArg) continue // they can be null, after all.

            response := returnArg resolve(trail, res)
            if(!response ok()) return response

            if(returnArg isResolved() && !returnArg instanceOf?(AddressOf)) {
                returnArgs[i] = returnArg getGenericOperand()
            }
        }

        /*
         * Try to resolve the call.
         *
         * We don't only have to find one definition, we have to find
         * the *best* one. For that, we're sticking to our fun score
         * system. A call can determine the score of a decl, based
         * mostly on the types of the arguments, the suffix, etc.
         *
         * Since we're looking for the best, we have to do the whole
         * trail from top to bottom
         */
        if(refScore <= 0) {
            if(debugCondition()) printf("\n===============\nResolving call %s\n", toString())
        	if(name == "super") {
				fDecl := trail get(trail find(FunctionDecl), FunctionDecl)
                superTypeDecl := fDecl owner getSuperRef()
                finalScore: Int
                ref = superTypeDecl getMeta() getFunction(fDecl getName(), null, this, finalScore&)
                if(finalScore == -1) {
                    res wholeAgain(this, "something in our typedecl's functions needs resolving!")
                    return Responses OK
                }
                if(ref != null) {
                    refScore = 1
                    expr = VariableAccess new(superTypeDecl getThisDecl(), token)
                    if(args empty?() && !ref getArguments() empty?()) {
                        for(declArg in fDecl getArguments()) {
                            args add(VariableAccess new(declArg, token))
                        }
                    }
                }
        	} else {
        		if(expr == null) {
				    depth := trail size() - 1
				    while(depth >= 0) {
				        node := trail get(depth, Node)
				        if(node resolveCall(this, res, trail) == -1) {
                            res wholeAgain(this, "Waiting on other nodes to resolve before resolving call.")
                            return Responses OK
                        }

                        if(ref) {
                            if(ref vDecl) {
                                closureIndex := trail find(FunctionDecl)

                                if(closureIndex > depth) { // if it's not found (-1), this will be false anyway
                                    closure := trail get(closureIndex) as FunctionDecl
                                    if(closure isAnon && expr == null) {
                                        closure markForPartialing(ref vDecl, "v")
                                    }
                                }
                            }
                        }
				        depth -= 1
				    }
			    } else if(expr instanceOf?(VariableAccess) && expr as VariableAccess getRef() != null && expr as VariableAccess getRef() instanceOf?(NamespaceDecl)) {
                    expr as VariableAccess getRef() resolveCall(this, res, trail)
                } else if(expr getType() != null && expr getType() getRef() != null) {
                    if(!expr getType() getRef() instanceOf?(TypeDecl)) {
                        message := "No such function %s%s for `%s`" format(name, getArgsTypesRepr(), expr getType() getName())
                        if(expr getType() isGeneric()) {
                            message += " (you can't call methods on generic types! you have to cast them first)"
                        }
                        res throwError(UnresolvedCall new(this, message))
                    }
                    tDecl := expr getType() getRef() as TypeDecl
		            meta := tDecl getMeta()
                    if(debugCondition()) printf("Got tDecl %s, resolving, meta = %s\n", tDecl toString(), meta == null ? "(nil)" : meta toString())
		            if(meta) {
		                meta resolveCall(this, res, trail)
		            } else {
		                tDecl resolveCall(this, res, trail)
		            }
		        }
            }
        }

        /*
         * Now resolve return type, generic type arguments, and interfaces
         */
        if(refScore > 0) {

            if(!resolveReturnType(trail, res) ok()) {
                res wholeAgain(this, "looping because of return type!")
                return Responses OK
            }

            if(!handleGenerics(trail, res) ok()) {
                res wholeAgain(this, "looping because of generics!")
                return Responses OK
            }

            if(!handleInterfaces(trail, res) ok()) {
                res wholeAgain(this, "looping because of interfaces!")
                return Responses OK
            }

            if(typeArgs size() > 0) {
                trail push(this)
                for(typeArg in typeArgs) {
                    response := typeArg resolve(trail, res)
                    if(!response ok()) {
                        trail pop(this)
                        res wholeAgain(this, "typeArg failed to resolve\n")
                        return Responses OK
                    }
                }
                trail pop(this)
            }

            unwrapIfNeeded(trail, res)

        }

        if(returnType) {
            response := returnType resolve(trail, res)
            if(!response ok()) return response
        }

        if(refScore <= 0) {

            // Still no match, and in the fatal round? Throw an error.
            if(res fatal) {
                message := "No such function"
                if(expr == null) {
                    message = "No such function %s%s" format(name, getArgsTypesRepr())
                } else if(expr getType() != null) {
                    if(res params veryVerbose) {
                        message = "No such function %s%s for `%s` (%s)" format(name, getArgsTypesRepr(),
                            expr getType() toString(), expr getType() getRef() ? expr getType() getRef() token toString() : "(nil)")
                    } else {
                        message = "No such function %s%s for `%s`" format(name, getArgsTypesRepr(), expr getType() toString())
                    }
                }

                if(ref) {
                    // If we have a near-match, show it here.
                    message += showNearestMatch(res params)
                    // TODO: add levenshtein distance
                } else {
                    if(res params helpful) {
                        // Try to find such a function in other modules in the sourcepath
                        similar := findSimilar(res)
                        if(similar) message += similar
                    }
                }
                res throwError(UnresolvedCall new(this, message))
            } else {
                res wholeAgain(this, "not resolved")
                return Responses OK
            }

        }

        return Responses OK

    }

    findSimilar: func (res: Resolver) -> String {

        buff := Buffer new()

        for(imp in res collectAllImports()) {
            module := imp getModule()

            fDecl := module getFunctions() get(name)
            if(fDecl) {
                buff append(" (Hint: there's such a function in "). append(imp getPath()). append(")")
            }
        }

        buff toString()

    }

    /**
     * If we have a ref but with a negative score, it means there's a function
     * with the right name, but that doesn't match in respect with the arguments
     */
    showNearestMatch: func (params: BuildParams) -> String {
        b := Buffer new()

        b append("\tNearest match is:\n\n\t\t%s\n" format(ref toString(this)))

        callIter := args iterator()
        declIter := ref args iterator()

        while(callIter hasNext?() && declIter hasNext?()) {
            declArg := declIter next()
            if(declArg instanceOf?(VarArg)) break
            callArg := callIter next()

            if(declArg getType() == null) {
                b append(declArg token formatMessage("\tbut couldn't resolve type of this argument in the declaration\n", ""))
                continue
            }

            if(callArg getType() == null) {
                b append(callArg token formatMessage("\tbut couldn't resolve type of this argument in the call\n", ""))
                continue
            }

            declArgType := declArg getType()
            if(declArgType isGeneric()) {
                "declArgType is originally %s" printfln(declArg toString())
                declArgType = declArgType realTypize(this)
                "and now it's %s" printfln(declArg toString())
            }

            score := callArg getType() getScore(declArgType)
            if(score < 0) {
                if(params veryVerbose) {
                    b append("\t..but the type of this arg should be `%s` (%s), not %s (%s)\n" format(declArgType toString(), declArgType getRef() ? declArgType getRef() token toString() : "(nil)",
                                                                                           callArg getType() toString(), callArg getType() getRef() ? callArg getType() getRef() token toString() : "(nil)"))
                } else {
                    b append("\t..but the type of this arg should be `%s`, not `%s`\n" format(declArgType toString(), callArg getType() toString()))
                }
                b append(token formatMessage("\t\t", "", ""))
            }
        }

        b toString()
    }

    unwrapIfNeeded: func (trail: Trail, res: Resolver) -> Response {

        parent := trail peek()

        if(ref == null || ref returnType == null) {
            res wholeAgain(this, "need ref and refType")
            return Responses OK
        }

        idx := 2
        while(parent instanceOf?(Cast)) {
            parent = trail peek(idx)
            idx += 1
        }

        //if(ref returnType isGeneric() && !isFriendlyHost(parent)) {
        if(!ref getReturnArgs() empty?() && !isFriendlyHost(parent)) {
            if(parent instanceOf?(Return)) {
                fDeclIdx := trail find(FunctionDecl)
                if(fDeclIdx != -1) {
                    fDecl := trail get(fDeclIdx) as FunctionDecl
                    retType := fDecl getReturnType()
                    if(!retType isResolved()) {
                        res wholeAgain(this, "Need fDecl returnType to be resolved")
                        return Responses OK
                    }
                    if(retType isGeneric()) {
                        // will be handled by Return resolve()
                        return Responses OK
                    }
                }
            }

            vType := getType() instanceOf?(TypeList) ? getType() as TypeList types get(0) : getType()
            vDecl := VariableDecl new(vType, generateTempName("genCall"), token)
            if(!trail addBeforeInScope(this, vDecl)) {
                if(res fatal) res throwError(CouldntAddBeforeInScope new(token, vDecl, this, trail))
                res wholeAgain(this, "couldn't add before scope")
                return Responses OK
            }

            seq := CommaSequence new(token)
            if(!trail peek() replace(this, seq)) {
                if(res fatal) res throwError(CouldntReplace new(token, this, seq, trail))
                // FIXME: what if we already added the vDecl?
                res wholeAgain(this, "couldn't unwrap")
                return Responses OK
            }

            // only modify ourselves if we could do the other modifications
            varAcc := VariableAccess new(vDecl, token)
            returnArgs add(varAcc)

            seq getBody() add(this)
            seq getBody() add(varAcc)

            res wholeAgain(this, "just unwrapped")
        }

        return Responses OK

    }

	/**
	 * In some cases, a generic function call needs to be unwrapped,
	 * e.g. when it's used as an expression in another call, etc.
	 * However, some nodes are 'friendly' parents to us, e.g.
	 * they handle things themselves and we don't need to unwrap.
	 * @return true if the node is friendly, false if it is not and we
	 * need to unwrap
	 */
    isFriendlyHost: func (node: Node) -> Bool {
        node isScope() ||
		node instanceOf?(CommaSequence) ||
		node instanceOf?(VariableDecl) ||
		(node instanceOf?(BinaryOp) && node as BinaryOp isAssign())
    }

    /**
     * Attempt to resolve the *actual* return type of the call, as oppposed
     * to the declared return type of our reference (a function decl).
     *
     * Mostly usefeful when the
     */
    resolveReturnType: func (trail: Trail, res: Resolver) -> Response {

        if(returnType != null) return Responses OK

        //printf("Resolving returnType of %s (=%s), returnType of ref = %s, isGeneric() = %s, ref of returnType of ref = %s\n", toString(), returnType ? returnType toString() : "(nil)",
        //    ref returnType toString(), ref returnType isGeneric() toString(), ref returnType getRef() ? ref returnType getRef() toString() : "(nil)")

        if(returnType == null && ref != null) {
            if(!ref returnType isResolved()) {
                res wholeAgain(this, "need resolve the return type of our ref to see if it's generic")
                return Responses OK
            }

            finalScore := 0
            if(ref returnType isGeneric()) {
                if(res params veryVerbose) printf("\t$$$$ resolving returnType %s for %s\n", ref returnType toString(), toString())
                returnType = resolveTypeArg(ref returnType getName(), trail, finalScore&)
                if((finalScore == -1 || returnType == null) && res fatal) {
                    res throwError(InternalError new(token, "Not enough info to resolve return type %s of function call\n" format(ref returnType toString())))
                }
            } else {
                returnType = ref returnType clone()
                returnType resolve(trail, res)
            }

            if(returnType != null && !realTypize(returnType, trail, res)) {
                res wholeAgain(this, "because couldn't properly realTypize return type.")
                returnType = null
            }
            if(returnType != null) {
                if(debugCondition()) printf("Realtypized return of %s = %s, isResolved = %s ?\n", toString(), returnType toString(), returnType isResolved() toString())
            }

            if(returnType) {
                if(debugCondition()) {
                    printf("Determined return type of %s (whose ref rt is %s) to be %s\n", toString(), ref getReturnType() toString(), returnType toString())
                    if(expr) printf("expr = %s, type = %s\n", expr toString(), expr getType() ? expr getType() toString() : "(nil)")
                }
                res wholeAgain(this, "because of return type")
                return Responses OK
            }
        }

        if(returnType == null) {
            if(res fatal) res throwError(InternalError new(token, "Couldn't resolve return type of function %s\n" format(toString())))
            return Responses LOOP
        }

        //"At the end of resolveReturnType(), the return type of %s is %s" format(toString(), getType() ? getType() toString() : "(nil)") println()
        return Responses OK

    }

    realTypize: func (type: Type, trail: Trail, res: Resolver) -> Bool {

        if(debugCondition()) printf("[realTypize] realTypizing type %s in %s\n", type toString(), toString())

        if(type instanceOf?(BaseType) && type as BaseType typeArgs != null) {
            baseType := type as BaseType
            j := 0
            for(typeArg in baseType typeArgs) {
                if(debugCondition())  printf("[realTypize] for typeArg %s (ref = %s)\n", typeArg toString(), typeArg getRef() ? typeArg getRef() toString() : "(nil)")
                if(typeArg getRef() == null) {
                    return false // must resolve it before
                }
                if(debugCondition())  printf("[realTypize] Ref of typeArg %s is a %s (and expr is a %s)\n", typeArg toString(), typeArg getRef() class name, expr ? expr toString() : "(nil)")

                // if it's generic-unspecific, it needs to be resolved
                if(typeArg getRef() instanceOf?(VariableDecl)) {
                    typeArgName := typeArg getRef() as VariableDecl getName()
                    finalScore := 0
                    result := resolveTypeArg(typeArgName, trail, finalScore&)
                    if(finalScore == -1) return false
                    if(debugCondition()) printf("[realTypize] result = %s\n", result ? result toString() : "(nil)")
                    if(result) baseType typeArgs set(j, VariableAccess new(result, typeArg token))
                }
                j += 1
            }
        }

        return true

    }

    /**
     * Add casts for interfaces arguments
     */
    handleInterfaces: func (trail: Trail, res: Resolver) -> Response {

        i := 0
        for(declArg in ref args) {
            if(declArg instanceOf?(VarArg)) break
            if(i >= args size()) break
            callArg := args get(i)
            if(declArg getType() == null || declArg getType() getRef() == null ||
               callArg getType() == null || callArg getType() getRef() == null) {
                res wholeAgain(this, "To resolve interface-args, need to resolve declArg and callArg")
                return Responses OK
            }
            if(declArg getType() getRef() instanceOf?(InterfaceDecl)) {
                if(!declArg getType() equals?(callArg getType())) {
                    args set(i, Cast new(callArg, declArg getType(), callArg token))
                }

            }
            i += 1
        }

        return Responses OK

    }

    /**
     * Resolve type arguments
     */
    handleGenerics: func (trail: Trail, res: Resolver) -> Response {

        j := 0
        for(implArg in ref args) {
            if(implArg instanceOf?(VarArg)) { j += 1; continue }
            implType := implArg getType()

            if(implType == null || !implType isResolved()) {
                res wholeAgain(this, "need impl arg type"); break // we'll do it later
            }
            if(!implType isGeneric() || implType pointerLevel() > 0) { j += 1; continue }

            //printf(" >> Reviewing arg %s in call %s\n", arg toString(), toString())

            callArg := args get(j)
            typeResult := callArg getType()
            if(typeResult == null) {
                res wholeAgain(this, "null callArg, need to resolve it first.")
                return Responses OK
            }

            isGood := ((callArg instanceOf?(AddressOf) && callArg as AddressOf isForGenerics) || typeResult isGeneric())
            if(!isGood) { // FIXME this is probably wrong - what if we want an address's address? etc.
                target : Expression = callArg
                if(!callArg isReferencable()) {
                    varDecl := VariableDecl new(typeResult, generateTempName("genArg"), callArg, nullToken)
                    if(!trail addBeforeInScope(this, varDecl)) {
                        printf("Couldn't add %s before %s, parent is a %s\n", varDecl toString(), toString(), trail peek() toString())
                    }
                    target = VariableAccess new(varDecl, callArg token)
                }
                addrOf := AddressOf new(target, target token)
                addrOf isForGenerics = true
                args set(j, addrOf)
            }
            j += 1
        }

        if(typeArgs size() == ref typeArgs size()) {
            return Responses OK // already resolved
        }

        //if(res params veryVerbose) printf("\t$$$$ resolving typeArgs of %s (call = %d, ref = %d)\n", toString(), typeArgs size(), ref typeArgs size())
        //if(res params veryVerbose) printf("trail = %s\n", trail toString())

        i := typeArgs size()
        while(i < ref typeArgs size()) {
            typeArg := ref typeArgs get(i)
            //if(res params veryVerbose) printf("\t$$$$ resolving typeArg %s\n", typeArg name)

            finalScore := 0
            typeResult := resolveTypeArg(typeArg name, trail, finalScore&)
            if(finalScore == -1) break
            if(typeResult) {
                result := typeResult instanceOf?(FuncType) ?
                    VariableAccess new("Pointer", token) :
                    VariableAccess new(typeResult, token)
                if (typeResult isGeneric()) {
                    result setRef(null) // force re-resolution - we may not be in the correct context
                }
                typeArgs add(result)
            } else break // typeArgs must be in order

            i += 1
        }

        for(typeArg in typeArgs) {
            response := typeArg resolve(trail, res)
            if(!response ok()) {
                if(res fatal) res throwError(InternalError new(token, "Couldn't resolve typeArg %s in call %s" format(typeArg toString(), toString())))
                return response
            }
        }

        if(typeArgs size() != ref typeArgs size()) {
            if(res fatal) {
                res throwError(InternalError new(token, "Missing info for type argument %s. Have you forgotten to qualify %s, e.g. List<Int>?" format(ref typeArgs get(typeArgs size()) getName(), ref toString())))
            }
            res wholeAgain(this, "Looping because of typeArgs\n")
        }

        return Responses OK

    }

    resolveTypeArg: func (typeArgName: String, trail: Trail, finalScore: Int@) -> Type {

        if(debugCondition()) printf("Should resolve typeArg %s in call %s\n", typeArgName, toString())

        if(ref && refScore > 0) {

            inFunctionTypeArgs := false
            for(typeArg in ref typeArgs) {
                if(typeArg getName() == typeArgName) {
                    inFunctionTypeArgs = true
                    break
                }
            }

            if(inFunctionTypeArgs) {
                j := 0
                for(arg in ref args) {
                    /* myFunction: func <T> (myArg: T)
                     * or:
                     * myFunction: func <T> (myArg: T[])
                     * or any level of nesting =)
                     */
                    argType := arg type
                    refCount := 0
                    while(argType instanceOf?(SugarType)) {
                        argType = argType as SugarType inner
                        refCount += 1
                    }
                    if(argType getName() == typeArgName) {
                        implArg := args get(j)
                        result := implArg getType()
                        realCount := 0
                        while(result instanceOf?(SugarType) && realCount < refCount) {
                            result = result as SugarType inner
                            realCount += 1
                        }
                        if(realCount == refCount) {
                            if(debugCondition()) printf(" >> Found arg-arg %s for typeArgName %s, returning %s\n", implArg toString(), typeArgName, result toString())
                            return result
                        }
                    }

                    /* myFunction: func <T> (myArg: Func -> T) */
                    if(argType instanceOf?(FuncType)) {
                        fType := argType as FuncType

                        if(fType returnType getName() == typeArgName) {
                            if(debugCondition()) " >> Hey, we have an interesting FuncType %s" printfln(fType toString())
                            implArg := args get(j)
                            if(implArg instanceOf?(FunctionDecl)) {
                                fDecl := implArg as FunctionDecl
                                if(fDecl inferredReturnType) {
                                    if(debugCondition()) " >> Got it from inferred return type %s!" printfln(fDecl inferredReturnType toString())
                                    return fDecl inferredReturnType
                                } else {
                                    if(debugCondition()) " >> We need the inferred return type. Looping" println()
                                    finalScore = -1
                                    return null
                                }
                            }
                        }
                    }

                    /* myFunction: func <T> (T: Class) */
                    if(arg getName() == typeArgName) {
                        implArg := args get(j)
                        if(implArg instanceOf?(VariableAccess)) {
                            if(implArg as VariableAccess getRef() == null) {
                                finalScore == -1
                                return null
                            }
                            result := BaseType new(implArg as VariableAccess getName(), implArg token)
                            result setRef(implArg as VariableAccess getRef()) // FIXME: that is experimental. is that a good idea?

                            if(debugCondition()) " >> Found ref-arg %s for typeArgName %s, returning %s" format(implArg toString(), typeArgName, result toString()) println()
                            return result
                        } else if(implArg instanceOf?(TypeAccess)) {
                            return implArg as TypeAccess inner
                        } else if(implArg instanceOf?(Type)) {
                            return implArg as Type
                        }
                    }
                    j += 1
                }

                /* myFunction: func <T> (myArg: OtherType<T>) */
                for(arg in args) {
                    if(arg getType() == null) continue

                    if(debugCondition()) printf("Looking for typeArg %s in arg's type %s\n", typeArgName, arg getType() toString())
                    result := arg getType() searchTypeArg(typeArgName, finalScore&)
                    if(finalScore == -1) return null // something has to be resolved further!
                    if(result) {
                        if(debugCondition()) printf("Found match for arg %s! Hence, result = %s (cause arg = %s)\n", typeArgName, result toString(), arg toString())
                        return result
                    }
                }
            }
        }

        if(expr != null) {
            if(expr instanceOf?(Type)) {
                /* Type<T> myFunction() */
                if(debugCondition()) printf("Looking for typeArg %s in expr-type %s\n", typeArgName, expr toString())
                result := expr as Type searchTypeArg(typeArgName, finalScore&)
                if(finalScore == -1) return null // something has to be resolved further!
                if(result) {
                    if(debugCondition()) printf("Found match for arg %s! Hence, result = %s (cause expr = %s)\n", typeArgName, result toString(), expr toString())
                    return result
                }
            } else if(expr getType() != null) {
                /* expr: Type<T>; expr myFunction() */
                if(debugCondition()) printf("Looking for typeArg %s in expr %s\n", typeArgName, expr toString())
                result := expr getType() searchTypeArg(typeArgName, finalScore&)
                if(finalScore == -1) return null // something has to be resolved further!
                if(result) {
                    if(debugCondition()) printf("Found match for arg %s! Hence, result = %s (cause expr type = %s)\n", typeArgName, result toString(), expr getType() toString())
                    return result
                }
            }
        }

        if(trail) {
            idx := trail find(TypeDecl)
            if(idx != -1) {
                tDecl := trail get(idx, TypeDecl)
                if(debugCondition()) "\n===\nFound tDecl %s" format(tDecl toString()) println()
                for(typeArg in tDecl getTypeArgs()) {
                    if(typeArg getName() == typeArgName) {
                        result := BaseType new(typeArgName, token)
                        result setRef(typeArg)
                        return result
                    }
                }

                if(tDecl getNonMeta() != null) {
                    result := tDecl getNonMeta() getInstanceType() searchTypeArg(typeArgName, finalScore&)
                    if(finalScore == -1) return null // something has to be resolved further!
                    if(result) {
                        if(debugCondition()) printf("Found in-TypeDecl match for arg %s! Hence, result = %s (cause expr type = %s)\n", typeArgName, result toString(), tDecl getNonMeta() getInstanceType() toString())
                        return result
                    }
                }
            }

            idx = trail find(FunctionDecl)
            while(idx != -1) {
                fDecl := trail get(idx, FunctionDecl)
                if(debugCondition()) "\n===\nFound fDecl %s, with %d typeArgs" format(fDecl toString(), fDecl getTypeArgs() size()) println()
                for(typeArg in fDecl getTypeArgs()) {
                    if(typeArg getName() == typeArgName) {
                        result := BaseType new(typeArgName, token)
                        result setRef(typeArg)
                        return result
                    }
                }
                idx = trail find(FunctionDecl, idx - 1)
            }
        }

        if(debugCondition()) printf("Couldn't resolve typeArg %s\n", typeArgName)
        return null

    }

    /**
     * @return the score of decl, respective to this function call.
     * This is used when resolving function calls, so that the function
     * decl with the highest score is chosen as a reference.
     */
    getScore: func (decl: FunctionDecl) -> Int {
        score := 0

        declArgs := decl args
        if(matchesArgs(decl)) {
            score += Type SCORE_SEED / 4
            if(debugCondition()) {
                printf("matchesArg, score is now %d\n", score)
            }
        } else {
            if(debugCondition()) {
                printf("doesn't match args, too bad!\n", score)
            }
            return Type NOLUCK_SCORE
        }

        if(decl getOwner() != null && isMember()) {
            // Will suffice to make a member call stronger
            score += Type SCORE_SEED / 4
        }

        if(suffix == null && decl suffix == null && !decl isStatic()) {
            // even though an unsuffixed call could be a call
            // to any of the suffixed versions, if both the call
            // and the decl don't have a suffix, that's a good sign.
            score += Type SCORE_SEED / 4
        }

        if(declArgs size() == 0) return score

        declIter : Iterator<Argument> = declArgs iterator()
        callIter : Iterator<Expression> = args iterator()

        while(callIter hasNext?() && declIter hasNext?()) {
            declArg := declIter next()
            callArg := callIter next()
            // avoid null types
            if(declArg instanceOf?(VarArg)) break
            if(declArg getType() == null) {
                if(debugCondition()) "Score is -1 because of declArg %s\n" format(declArg toString()) println()
                return -1
            }
            if(callArg getType() == null) {
                if(debugCondition()) "Score is -1 because of callArg %s\n" format(callArg toString()) println()
                return -1
            }

            declArgType := declArg getType()
            if (declArgType isGeneric()) {
                finalScore := 0
                declArgType = declArgType realTypize(this)
            }

            typeScore := callArg getType() getScore(declArgType refToPointer())
            if(typeScore == -1) {
                if(debugCondition()) {
                    printf("-1 because of type score between %s and %s\n", callArg getType() toString(), declArgType refToPointer() toString())
                }
                return -1
            }

            score += typeScore

            if(debugCondition()) {
                printf("typeScore for %s vs %s == %d    for call %s (%s vs %s) [%p vs %p]\n",
                    callArg getType() toString(), declArgType refToPointer() toString(), typeScore, toString(),
                    callArg getType() getGroundType() toString(), declArgType refToPointer() getGroundType() toString(),
                    callArg getType() getRef(), declArgType getRef())
            }
        }

        if(debugCondition()) {
            printf("Final score = %d\n", score)
        }

        return score
    }

    /**
     * Returns true if decl has a signature compatible with this function call
     */
    matchesArgs: func (decl: FunctionDecl) -> Bool {
        declArgs := decl args size()
        callArgs := args size()

        // same number of args
        if(declArgs == callArgs) {
            return true
        }

        // or, vararg
        if(decl args size() > 0) {
            last := decl args last()

            // and less fixed decl args than call args ;)
            if(last instanceOf?(VarArg) && declArgs - 1 <= callArgs) {
                return true
            }
        }

        if(debugCondition()) {
            "Args don't match! declArgs = %d, callArgs = %d" format(declArgs, callArgs) println()
        }

        return false
    }

    getType: func -> Type { returnType }

    isMember: func -> Bool {
        (expr != null) &&
        !(expr instanceOf?(VariableAccess) &&
          expr as VariableAccess getRef() != null &&
          expr as VariableAccess getRef() instanceOf?(NamespaceDecl)
        )
    }

    getArgsRepr: func -> String {
        sb := Buffer new()
        sb append("(")
        isFirst := true
        for(arg in args) {
            if(!isFirst) sb append(", ")
            sb append(arg toString())
            if(isFirst) isFirst = false
        }
        sb append(")")
        return sb toString()
    }

    getArgsTypesRepr: func -> String {
        sb := Buffer new()
        sb append("(")
        isFirst := true
        for(arg in args) {
            if(!isFirst) sb append(", ")
            sb append(arg getType() ? arg getType() toString() : "<unknown type>")
            if(isFirst) isFirst = false
        }
        sb append(")")
        return sb toString()
    }

    toString: func -> String {
        (expr ? expr toString() + " " : "") + (ref ? ref getName() : name) + getArgsRepr()
    }

    replace: func (oldie, kiddo: Node) -> Bool {
        if(oldie == expr) {
            expr = kiddo;
            return true;
        }

        args replace(oldie as Expression, kiddo as Expression)
    }

    setReturnArg: func (retArg: Expression) {
        if(returnArgs empty?()) returnArgs add(retArg)
        else                     returnArgs[0] = retArg
    }
    getReturnArgs: func -> List<Expression> { returnArgs }

    getRef: func -> FunctionDecl { ref }
    setRef: func (=ref) { refScore = 1; /* or it'll keep trying to resolve it =) */ }

	getArguments: func ->  ArrayList<Expression> { args }

}


/**
 * Error thrown when a type isn't defined
 */
UnresolvedCall: class extends Error {

    call: FunctionCall
    init: func (.call, .message) {
        init(call token, call, message)
    }

    init: func ~withToken(.token, =call, .message) {
        super(call expr ? call expr token enclosing(call token) : call token, message)
    }

}
