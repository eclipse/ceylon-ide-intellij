import com.intellij.lang {
    ASTNode
}
import com.intellij.openapi.application {
    ApplicationManager
}
import com.intellij.openapi.diagnostic {
    Logger
}
import com.intellij.openapi.util {
    Ref
}
import com.intellij.psi {
    PsiFile,
    TokenType
}
import com.intellij.psi.impl.source.tree {
    CompositeElement,
    LeafPsiElement,
    PsiWhiteSpaceImpl,
    TreeElement
}
import com.intellij.psi.tree {
    IElementType
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}

import java.lang {
    IntArray,
    UnsupportedOperationException
}

import org.antlr.runtime {
    CommonToken,
    Token
}
import java.util {
    List,
    Queue,
    LinkedList,
    ArrayList,
    Collections
}

Logger logger = Logger.getInstance(`IdeaCeylonParser`);

shared class CompilationUnitTranslator(PsiFile file, Boolean verbose)
        extends Visitor() {

    late variable CompositeElement parent;
    late variable Queue<CommonToken> customizedTokens;

    variable value index = 0;

    void dump(ASTNode root, String indent) {
        print(indent
                + root.elementType.string
                + (root is LeafPsiElement then " (``root.text``)" else ""));
        for (child in root.getChildren(null)) {
            dump(child, indent + "  ");
        }
    }

    shared ASTNode translateToAstNode(Tree.CompilationUnit rootNode,
            List<CommonToken> originalTokens) {
        customizedTokens = LinkedList<CommonToken>();
        value lastToken = Ref<CommonToken>();
        for (token in originalTokens) {
            Integer lastStopIndex;
            Boolean lastWasEof;
            if (!lastToken.null) {
                lastStopIndex = lastToken.get().stopIndex;
                lastWasEof = lastToken.get().type == CeylonLexer.eof;
            }
            else {
                lastStopIndex = -1;
                lastWasEof = false;
            }
            if (!lastWasEof, lastStopIndex != token.startIndex - 1) {
                value badToken
                        = CommonToken(token.inputStream,
                            -2, 0,
                            lastStopIndex + 1,
                            token.startIndex - 1);
                if (badToken.stopIndex>=badToken.startIndex) {
                    customizedTokens.add(badToken);
                }
            }
            customizedTokens.add(token);
            lastToken.set(token);
        }
        if (lastToken.get().stopIndex<file.textLength) {
            value badToken
                    = CommonToken(lastToken.get().inputStream,
                        -2, 0,
                        lastToken.get().stopIndex + 1,
                        file.textLength - 1);
            if (badToken.stopIndex>=badToken.startIndex) {
                customizedTokens.add(badToken);
            }
        }
        visit(rootNode);
        if (verbose) {
            dump(parent, "");
        }
        return parent;
    }

    shared actual void visit(Tree.CompilationUnit that) {
        super.visit(that);
        while (!customizedTokens.empty) {
            value token = customizedTokens.remove();
            if (token.type != CeylonLexer.eof) {
                value elementType = getElementType(token.type);
                parent.rawAddChildrenWithoutNotifications(buildLeaf {
                    ceylonNode = null;
                    type = elementType;
                    token = token;
                });
            }
            if (verbose, !parserConstants.nodesAllowedAtEof.contains(token.type)) {
                logger.error("Unexpected token ``token`` in ``file.name``");
            }
        }
        value parentAndFileTextLength = IntArray(2);
        ApplicationManager.application.runReadAction(() {
            parentAndFileTextLength.set(0, parent.textLength);
            parentAndFileTextLength.set(1, file.textLength);
        });
        value parentTextLength = parentAndFileTextLength.get(0);
        value fileTextLength = parentAndFileTextLength.get(1);
        if (parentTextLength<fileTextLength) {
            value notParsed = file.text.substring(parentTextLength);
            parent.rawAddChildrenWithoutNotifications(LeafPsiElement(TokenType.badCharacter, notParsed));
        }
    }

    shared actual void visitAny(Node that) {
        value type = NodeToIElementTypeMap.get(that);
        if (!exists type) {
            logger.error("Unknown IElementType for ``that`` in ``that.unit.fullPath``");
            return;
        }

        if (that is Tree.CompilationUnit) {
            parent = CompositeElement(type);
        }

        if (is Tree.DocLink that) {
            return;
        }
        index = consumeTokens(that, index, true);
        value token = that.mainToken;
        value visitor = OrderedChildrenVisitor();
        try {
            that.visitChildren(visitor);
        }
        catch (Exception e) {
            that.handleException(e, visitor);
        }
        if (token exists, that.token exists,
            visitor.children.empty,
            exists peek = customizedTokens.peek()) {
            if (getTokenLength(peek)
                    == that.endIndex.intValue() - that.startIndex.intValue()) {
                value toRemove = customizedTokens.remove();
                parent.rawAddChildrenWithoutNotifications(buildLeaf {
                    ceylonNode = that;
                    type = type;
                    token = toRemove;
                });
                if (verbose) {
                    print("t \"``toRemove.text``\"");
                }
                index +=getTokenLength(toRemove);
            } else {
                value comp = CompositeElement(type);
                while (index<that.endIndex.intValue()) {
                    value toRemove = customizedTokens.remove();
                    value elementType = getElementType(token.type);
                    comp.rawAddChildrenWithoutNotifications(buildLeaf {
                        ceylonNode = null;
                        type = elementType;
                        token = toRemove;
                    });
                    if (verbose) {
                        print("t \"" + toRemove.text + "\"");
                    }
                    index +=getTokenLength(toRemove);
                }
                parent.rawAddChildrenWithoutNotifications(comp);
            }
            assert (index>=that.endIndex.intValue());
        }
        else {
            value oldParent = parent;
            if (!that is Tree.CompilationUnit) {
                value newParent = CompositeElement(type);
                this.parent = newParent;
                oldParent.rawAddChildrenWithoutNotifications(newParent);
            }
            parent.putUserData(parserConstants.ceylonNodeKey, that);
            for (child in visitor.children) {
                visitAny(child);
            }
            index = consumeTokens(that, index, false);
            parent = oldParent;
        }
    }

    IElementType getElementType(Integer idx)
            => idx == -2
            then TokenType.badCharacter
            else TokenUtil.fromInt(idx);

    TreeElement buildLeaf(Node? ceylonNode, IElementType type, Token token) {
        String tokenText;
        value txt = token.text;
        if (txt.size != getTokenLength(token)) {
            switch (token.type)
            case (CeylonLexer.pidentifier
                | CeylonLexer.aidentifier
                | CeylonLexer.lidentifier) {
                tokenText = "\\i" + txt;
            }
            else case (CeylonLexer.uidentifier) {
                tokenText = "\\I" + txt;
            }
            else case (CeylonLexer.eof) {
                tokenText = "";
            }
            else {
                throw UnsupportedOperationException("Unsupported token type ``token``");
            }
        }
        else {
            tokenText = txt;
        }

        if (parserConstants.leavesToWrap.contains(type)) {
            value comp = CompositeElement(type);
            value leaf = LeafPsiElement(TokenUtil.fromInt(token.type), tokenText);
            comp.rawAddChildrenWithoutNotifications(leaf);
            comp.putUserData(parserConstants.ceylonNodeKey, ceylonNode);
            return comp;
        } else if (type == TokenType.whiteSpace
                || token.type == CeylonLexer.ws) {
            return PsiWhiteSpaceImpl(tokenText);
        } else {
            return LeafPsiElement(getElementType(token.type), tokenText);
        }
    }

    Integer consumeTokens(Node that, Integer index, Boolean before) {
        value targetIndexOrNull =
                before
                    then that.startIndex
                    else that.endIndex;
        if (!exists targetIndexOrNull) {
            return index;
        }
        value targetIndex = targetIndexOrNull.intValue();
        if (index>targetIndex) {
            if (verbose) {
                print("WARN : index (``index``) > targetIndex (``targetIndexOrNull``)");
            }
            return index;
        }

        variable value i = index;
        while (i<targetIndex) {
            value token = customizedTokens.remove();
            value text = token.text;
            value elementType = getElementType(token.type);
            if (token.type == CeylonLexer.lineComment
                    && text.endsWith("\n")) {
                parent.rawAddChildrenWithoutNotifications(LeafPsiElement(elementType, text.exceptLast));
                parent.rawAddChildrenWithoutNotifications(PsiWhiteSpaceImpl("\n"));
            } else {
                parent.rawAddChildrenWithoutNotifications(buildLeaf(null, elementType, token));
            }
            i += getTokenLength(token);
            if (verbose) {
                print("c \"``text``\"");
            }
        }
        assert (i == targetIndex);
        return i;
    }

    Integer getTokenLength(Token token)
            => if (is CommonToken token)
            then token.stopIndex - token.startIndex + 1
            else token.text.size;

    class OrderedChildrenVisitor() extends Visitor() {

        value list = ArrayList<Node>();

        visitAny(Node that) => list.add(that);

        shared List<Node> children {
            Collections.sort(list, (Node o1, Node o2) {
                value idx1 = o1.startIndex;
                value idx2 = o2.startIndex;
                if (!idx1 exists) {
                    return idx2 exists then 1 else 0;
                }
                if (!idx2 exists) {
                    return -1;
                }
                return idx1.compareTo(idx2);
            });
            return list;
        }

    }
}
