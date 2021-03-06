classdef abstractMeganetElement < handle
% need to find better name for this, but here go
% some derivative functions that simplify building Jacobians etc. 
%
% those methods are used for all 'elements' of our networks
% (transformations, layers, networks, blocks,...)
%
% Abstractly, a MeganetElement does the following
%
%  Y_k+1 = apply(theta,Y_k)
%
%
% where 'apply' can be everything from a single affine transformation to a
% ResNet block. All these operations have a similar structure, e.g.,
% provide derivatives w.r.t. theta and Y_k, ... 
%
%
% Example: Consider a Neural network consisting of two layers. 
% T1  = dense([12,8]);
% T2  = dense([24,12])
% net = NN({T1, T2});
%
% Calling apply(net,theta,Y) results in a nested evaluation
%
% apply(net,theta,Y) = apply(T2, theta2, apply(T1, theta1, Y)); 
%
% This example shows that each element of the network needs the following
% functions
%
%  split - partition the input parameters into parameters of elements
%          describing this object (in our case theta -> theta1, theta2 
%  apply - evaluate the action (e.g., forward propagation, filtering, ..)
%          in many cases this involves calling 'apply' for other objects
%          (e.g., for different layers, kernels,...)
%  Jthetamv  - compute the action of the Jacobian w.r.t theta on a vector
%  JthetaTmv - compute the action of the transpose(Jacobian) w.r.t theta on a vector
%  JYmv      - compute the action of the Jacobian w.r.t Y on a vector
%  JYTmv     - compute the action of the transpose(Jacobian) w.r.t Y on a vector
%  
% In addition, elements of this class also need to provide the folowing
% methods
%
%  nTheta   - return the number of parameters, numel(theta) for this
%              element (may have to ask lower-level elements for this)
%  nFeatIn  - number of input features
%  nFeatOut - number of output features
%  initTheta - initialize parameters


methods
    function n = nTheta(~)
        % function n = nTheta(this)
        %
        % return number of parameters, i.e., numel(theta)
        n = [];
        error('children of abstractMeganetElement must provide method nTheta');
    end
    function n = nFeatIn(~)
        % function n = nFeatIn(this)
        %
        % return number of input features, i.e., size(Y,1)
        n = [];
        error('children of abstractMeganetElement must provide method nFeatIn');
    end
    function n = nFeatOut(~)
        % function n = nFeatOut(this)
        %
        % return number of output features, i.e., size(Y_N,1)
        n = [];
        error('children of abstractMeganetElement must provide method nFeatOut');
    end
    function varargout = split(~,~)
        % function varargout = split(this,theta)
        %
        % split theta into different parts used by sub-elements.
        varargout = [];
        error('children of abstractMeganetElement must provide method split');
    end
    function theta = initTheta(~,~)
        % function theta = initTheta(this)
        %
        % initialize theta
        theta = [];
        error('children of abstractMeganetElement must provide method initTheta');
    end
        
        % ---------derivatives for Y --------
        function dY = JYTmv(this,Wdata,W,theta,Y,tmp)
            % dY = abstractMeganetElement.JYTmv(this,W,theta,Y,tmp)
            %
            % computes dY = transpose(J_Y(theta,Y))*W 
            %
            % Input:
            %
            %    W     - vector or matrix
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   dY     - directional derivative, numel(dY)==numel(Y)
            [~,dY] = JTmv(this,Wdata,W,theta,Y,tmp);
        end
        function [dYdata,dY] = JYmv(this,dY,theta,Y,tmp)
            % dZ = abstractMeganetElement.JYTmv(this,W,theta,Y,tmp)
            %
            % computes dZ = J_Y(theta,Y)*dY
            %
            % Input:
            %
            %    dY    - perturbation in Y
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   dZ     - directional derivative, numel(dZ)==numel(Z)
            [dYdata,dY] = Jmv(this,[],dY,theta,Y,tmp);
        end
        
        function [this,theta] = prolongateWeights(this,theta)
            
        end
        
        
        function [Z,J] = linearizeY(this,theta,Y)
            % function [K,dK] = linearizeY(this,theta,Y)
            %
            % linearization with respect to Y, i.e., 
            %
            % Z(theta,Y+dY) \approx Z(theta,Y) + J*dY
            % 
            % Input:
            %
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   Z     - current output features
            %   J     - Jacobian, LinearOperator
            [Z,~,tmp]  = apply(this,theta,Y);
            J        = getJYOp(this,theta,Y,tmp);
        end
        
        function J = getJYOp(this,theta,Y,tmp)
            % J = getJYOp(this,theta,Y,tmp)
            %
            % constructs Jacobian w.r.t. Y around current (theta,Y)
            %
            % Input:
            %
            %    W     - vector or matrix
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   dY     - directional derivative, numel(dY)==numel(Y)
            
            if nargin<4; tmp=[]; end
            nex    = numel(Y)/nFeatIn(this);
            m      = nex*nDataOut(this);
            n      = numel(Y);
            Amv    = @(x) JYmv(this,x,theta,Y,tmp);
            ATmv   = @(x) JYTmv(this,x,[],theta,Y,tmp);
            J      = LinearOperator(m,n,Amv,ATmv);
        end

        

        % -------- derivatives for theta ---------
        function [dYdata,dY] = Jthetamv(this,dtheta,theta,Y,tmp)
            % dZ = abstractMeganetElement.Jthetamv(this,W,theta,Y,tmp)
            %
            % computes dZ = J_theta(theta,Y)*dtheta
            %
            % Input:
            %
            %    dtheta- perturbation in theta
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   dZ     - directional derivative, numel(dZ)==numel(Z)
            [dYdata,dY] = Jmv(this,dtheta,[],theta,Y,tmp);
        end
        
        function dtheta = JthetaTmv(this,Wdata,W,theta,Y,tmp)
            % dY = abstractMeganetElement.JthetaTmv(this,W,theta,Y,tmp)
            %
            % computes dtheta = transpose(J_theta(theta,Y))*W 
            %
            % Input:
            %
            %    W     - vector or matrix
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   dtheta - directional derivative, numel(dtheta)==numel(theta)
            dtheta = JTmv(this,Wdata,W,theta,Y,tmp);
        end
        
        
        function J = getJthetaOp(this,theta,Y,tmp)
            % J = abstractMeganetElement.getJthetaOp(this,theta,Y,tmp)
            %
            % constructs Jacobian w.r.t. theta as LinearOperator
            %
            % Input:
            %
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   J     - Jacobian, LinearOperator
            if nargin<4; tmp=[]; end
            nex    = numel(Y)/nFeatIn(this);
            m      = nex*nDataOut(this);
            n      = numel(theta);
            Amv    = @(x) Jthetamv(this,x,theta,Y,tmp);
            ATmv   = @(x) JthetaTmv(this,x,[],theta,Y,tmp);
            J      = LinearOperator(m,n,Amv,ATmv);
        end

        function [Z,J] = linearizeTheta(this,theta,Y)
            % function [K,J] = linearizeY(this,theta,Y)
            %
            % linearization with respect to theta, i.e., 
            %
            % Z(theta+dth,Y) \approx Z(theta,Y) + J*dth
            %
            % Input:
            %
            %    theta - current theta
            %    Y     - current Y
            %
            % Output: 
            %
            %   Z     - output features
            %   J     - Jacobian, LinearOperator
            [Z,~,tmp] = apply(this,theta,Y);
            J       = getJthetaOp(this,theta,Y,tmp);
        end
        
        % --------  combined derivatives ----------
        function [dZdata,dZ] = Jmv(this,dtheta,dY,theta,Y,tmp)
            % dZ = abstractMeganetElement.Jmv(this,dtheta,dY,theta,Y,tmp)
            %
            % computes dZ = J_theta(theta,Y)*dtheta + J_Y(theta,Y)*dY
            %
            % Input:
            %
            %    dtheta- perturbation in theta
            %    dY    - perturbation of input features Y
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   dZ     - directional derivative, numel(dZ)==numel(Z)
            
            if nargin<4; tmp=[]; end
            if isempty(dtheta) || norm(dtheta(:))==0
                dZdata = 0;
                dZ     = 0;
            else
                [dZdata,dZ] = Jthetamv(this,dtheta,theta,Y,tmp);
            end

            if not(isempty(dY)) && norm(dY(:))>0
                [dZdt,dZt] = JYmv(this,dY,theta,Y,tmp);
                dZdata = dZdata + dZdt;
                dZ     = dZ + dZt;
            end
        end
        
        function [dtheta,dY] = JTmv(this,Wdata,W,theta,Y,tmp,doDerivative)
            % dZ = abstractMeganetElement.JTmv(this,Z,theta,Y,tmp)
            %
            % computes [dtheta;dY] = [J_theta(theta,Y)'; J_Y(theta)']*Z
            %
            % Input:
            %
            %    Z     - perturbation of output
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %    doDerivative - vector with two elements for theta and Y
            %    derivative. Important only when nargout==1. default=[1,0];
            %
            % Output: There are three different modes for the output
            %  
            %   if nargout==2
            %       dtheta - directional derivative, numel(dtheta)==numel(theta)
            %       dY     - directional derivative, numel(dY)==numel(dY)
            %   elseif nargout==1 && all(doDerivative==1)
            %       dtheta = [dtheta(:); dY(:)]
            %   else
            %       dtheta = dtheta
            %   end
            %
            % There are different modes for the output. If nargout==2 
            
            if not(exist('tmp','var')); tmp=[]; end
            if not(exist('doDerivative','var')) || isempty(doDerivative); 
               doDerivative =[1;0]; 
            end
            dtheta = JthetaTmv(this,Wdata,W,theta,Y,tmp);
            if nargout==2 || doDerivative(2)==1
                dY     = JYTmv(this,Wdata,W,theta,Y,tmp);
            end
            
            if nargout==1 && all(doDerivative==1)
                dtheta = [dtheta(:); dY(:)];
            end
        end
        
        function [theta] = prolongateConvStencils(this,theta,getRP)
            % prolongate convolution stencils. By default do nothing.
        end
        function [theta] = restrictConvStencils(this,theta,getRP)
            % restrict convolution stencils. By default do nothing.
        end
                
        function J = getJOp(this,theta,Y,tmp)
            % J = abstractMeganetElement.getJOp(this,Z,theta,Y,tmp)
            %
            % constructs Jacobian J(theta,Y) such that
            %
            % Z(theta+dth,Y+dY) \approx Z(theta,Y) + J*[dth; dY]
            %
            % Input:
            %
            %    theta - current theta
            %    Y     - current Y
            %    tmp   - intermediates used in derivative computations
            %            (e.g., hidden features, activations, derivatives,
            %            ... )
            %
            % Output: 
            %
            %   J     - Jacobian, LinearOperator
            
            if nargin<4; tmp=[]; end

            nex    = numel(Y)/nFeatIn(this);
            m      = nex*nDataOut(this);
            nth    = numel(theta);
            nY     = numel(Y);
            Amv    = @(x) Jmv(this,x(1:nth),x(nth+1:end),theta,Y,tmp);
            ATmv   = @(x) JTmv(this,x,[],theta,Y,tmp,[1;1]);
            J      = LinearOperator(m,nth+nY,Amv,ATmv);
        end

        
    end
    
end


