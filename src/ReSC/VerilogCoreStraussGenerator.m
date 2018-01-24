%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright (C) 2016 N. Eamon Gaffney
%%
%% This program is free software; you can resdistribute and/or modify it under
%% the terms of the MIT license, a copy of which should have been included with
%% this program at https://github.com/arminalaghi/scsynth
%%
%% References:
%% %% A. Alaghi and J. P. Hayes, "A spectral transform approach to stochastic
%% circuits," 2012 IEEE 30th International Conference on Computer Design (ICCD),
%% Montreal, QC, 2012, pp. 315-321. doi: 10.1109/ICCD.2012.6378658
%%
%% A. Alaghi and J. P. Hayes, "STRAUSS: Spectral Transform Use in Stochastic
%% Circuit Synthesis," in IEEE Transactions on Computer-Aided Design of
%% Integrated Circuits and Systems, vol. 34, no. 11, pp. 1770-1783, Nov. 2015.
%% doi: 10.1109/TCAD.2015.2432138
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function VerilogCoreStraussGenerator (degree, moduleName,...
                                      hardCodeConstants=true,
                                      singleConstantBitstream=true, coeff=[],...
                                      m_coeff=0, symmetric=false)

  %Generates a STRAUSS in verilog whose inputs and outputs
  %remain in stochastic format
  
  %Parameters:
  % degree    : the degree of the Bernstein polynomial
  % moduleName: the name of the verilog module
  
  %Optional Parameters:
  % hardCodeConstants: if true, constant input is simply a random bitstream, and
  %                    stochastic number generation is hard coded into the
  %                    module (default=true)
  % singleConstantBitsream: only relevant if hardCodeConstants is true, if true,
  %                         use one random bitstream for all constants rather
  %                         than an independent one for each (default true)
  % coeff: Bernstein coefficients, required with hardCodeConstants and
  %        unnecessary otherwise
  % m_coeff: number of bits in representation of coefficients, required with
  %          hardCodeConstants, unnecessary otherwise
  % symmetric: generate the STRAUSS constants symmetrically or asymetrically,
  %            the latter being optimized for smaller circuit design. Irrelevant
  %            if constants aren't hard coded (default false)
  
  fileName = sprintf('%s.v', moduleName);
  header = ['/*\n * This file was generated by the scsynth tool, and is ava',...
            'ilablefor use under\n * the MIT license. More information can ',...
            'be found at\n * https://github.com/arminalaghi/scsynth/\n */\n'];
  
  fp = fopen(fileName, 'w');
  
  fprintf(fp, header);
  fprintf(fp, 'module %s( //the stochastic core of an ReSC\n', moduleName);
	fprintf(fp, '\tinput [%d:0] x, //independent copies of x\n', degree - 1);
  if hardCodeConstants
    if singleConstantBitstream
      fprintf(fp, '\tinput [%d:0] randw, //for constant generation\n', m_coeff);
    else
      for i=0:degree
        fprintf(fp, '\tinput [%d:0] randw%d, //for constant generation\n', i,...
                m_coeff);
      end
    end
  else
    fprintf(fp, '\tinput [%d:0] w, //Bernstein coefficients\n', degree);
  end
  fprintf(fp, '\toutput reg z //output bitsream\n);\n\n');
  
  if symmetric
    tt = BernToTTSymQuantized(coeff, m_coeff);
  else
    tt = GreedySearchForAsymScalable(coeff, m_coeff);
  end
  
  if hardCodeConstants
    one_values = [];
    zero_values = [];
    prob_table = zeros(1, 4);
    %%fprintf(fp, '\twire [%d:0] w;\n', degree);
    for i=0:length(tt)-1
		  fprintf(fp, '\twire wire%d_1;\n', i);
      %%fprintf(fp, '\tassign w[%d] = wire%d_1;\n', i, i);
      temp = round(tt(i+1)*(2^m_coeff))/(2^m_coeff);
      for j=1:m_coeff+1
        if(temp == 1)
          if j == 1
            one_values = [one_values, i];
          else
            fprintf(fp, '\tassign wire%d_%d = 1;\n', i, j);
          end
          break;
        elseif(temp == 0)
          if j == 1
            one_values = [zero_values, i];
          else
            fprintf(fp, '\tassign wire%d_%d = 0;\n', i, j);
          end
          break;
        else
          if(size(find(prob_table(:, 1) == temp), 1) ~= 0) %prob exists
            index = find(prob_table(:, 1) == temp);
            temp2 = prob_table(index, :);
            if(size(find(temp2(:, 2) == j), 1) ~= 0) %the same level
              index2 = find(temp2(:, 2) == j);
              temp2 = temp2(index2, :);
              fprintf(fp, '\tassign wire%d_%d = wire%d_%d;\n', i, j,...
                      temp2(1, 3), temp2(1, 4));
              break;
            end
          end
  
          if(size(find(prob_table(:, 1) == 1 - temp), 1) ~= 0) %inverse
            index = find(prob_table(:, 1) == 1 - temp);
            temp2 = prob_table(index, :);
            if(size(find(temp2(:, 2) == j), 1) ~= 0) %the same level
              index2 = find(temp2(:, 2) == j);
              temp2 = temp2(index2, :);
              fprintf(fp, '\tassign wire%d_%d = ~wire%d_%d;\n', i, j,...
                      temp2(1, 3), temp2(1, 4));
              break;
            end
          end
  
          new_row = [temp, j, i, j];
          prob_table = [prob_table ; new_row];
          if singleConstantBitstream
            rand = 'randw';
          else
            rand = sprintf('randw%d', i);
          end
          if(temp < 0.5)
            fprintf(fp, '\twire wire%d_%d;\n', i, j+1);
            fprintf(fp, '\tassign wire%d_%d = (%s[%d] & wire%d_%d);\n', i, j,...
                    rand, m_coeff - j, i, j+1);
            temp = 2*temp;
          else
            fprintf(fp, '\twire wire%d_%d;\n', i, j+1);
            fprintf(fp, '\tassign wire%d_%d = (%s[%d] | wire%d_%d);\n', i, j,...
                    rand, m_coeff - j, i, j+1);
            temp = 2*temp - 1;
          end
        end
      end
      fprintf(fp, '\n');
    end
  end
  
	fprintf(fp, '\talways @(*) begin\n');
	fprintf(fp, '\t\tcase (x)\n');
  for i=1:length(tt)
    if hardCodeConstants
      if any(one_values==i-1)
        fprintf(fp, '\t\t\t%d''d%d: z = 1;\n', degree, i-1);
      elseif any(zero_values==i-1)
        fprintf(fp, '\t\t\t%d''d%d: z = 0;\n', degree, i-1);
      else
        fprintf(fp, '\t\t\t%d''d%d: z = wire%d_1;\n', degree, i-1, tt(i));
      end
    else
      fprintf(fp, '\t\t\t%d''d%d: z = w[%d];\n', degree, i-1, tt(i));
    end
  end
  fprintf(fp, '\t\t\tdefault: z = 0;\n');
	fprintf(fp, '\t\tendcase\n');
	fprintf(fp, '\tend\n');
  fprintf(fp, 'endmodule\n');
  
  fclose(fp);
end